#!/usr/bin/env python3
"""
build_audio.py -- procedural sound design + score builder for OBJECT 9 (146 s film).

Reads timeline.json (shot start times) and every shots/<name>/cues.json that
exists, synthesizes every cue procedurally, lays ambience beds with
crossfades, adds a dark minimal horror score, runs a small synthetic
convolution reverb per context, soft-limits the master, and writes
build/audio.wav (48 kHz stereo, exactly 146 s).

Usage:
    python3 audio/build_audio.py                  # full build -> build/audio.wav
    python3 audio/build_audio.py --self-test       # also render build/audio_tests/*.wav
    python3 audio/build_audio.py --use-test-cues   # read build/test_cues/ instead of shots/

No files outside audio/ and build/ are written or modified.
"""
import os
import sys
import json
import zlib
import argparse

import numpy as np
from scipy import signal as sig
from scipy.io import wavfile

# --------------------------------------------------------------------------
# Paths / constants
# --------------------------------------------------------------------------
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIMELINE_PATH = os.path.join(ROOT, "timeline.json")
SHOTS_DIR = os.path.join(ROOT, "shots")
TEST_CUES_DIR = os.path.join(ROOT, "build", "test_cues")
OUT_WAV = os.path.join(ROOT, "build", "audio.wav")
TEST_DIR = os.path.join(ROOT, "build", "audio_tests")

SR = 48000
FILM_DUR = 146.0
N_TOTAL = int(round(FILM_DUR * SR))

ALLOWED_CUE_TYPES = {
    "typewriter_key", "radio_static", "radio_signal", "morse", "engine_idle",
    "engine_rev", "wind_gust", "door_grind", "door_slam", "bolt_lock",
    "power_down", "power_up", "light_flicker", "fluorescent_buzz",
    "footsteps", "heartbeat", "breath", "stinger", "drone_swell", "shriek",
    "growl", "gore_hit", "body_fall", "ks23_shot", "pump_rack", "ak_burst",
    "ppsh_burst", "makarov_shot", "flare_shot", "grenade_pin", "explosion",
    "glass_break", "metal_clang", "tank_burst", "liquid_splash", "impact",
    "whoosh", "music_hit",
}

ALLOWED_AMBIENCE = {"blizzard", "interior_hum", "interior_dead", "hangar", "none"}

REVERB_FOR_AMBIENCE = {
    "blizzard": "outdoor",
    "interior_hum": "metal_room",
    "interior_dead": "metal_room",
    "hangar": "hangar",
    "none": "dry",
}

DB = lambda db: 10.0 ** (db / 20.0)


def warn(msg):
    print(f"[build_audio] WARNING: {msg}", file=sys.stderr)


def info(msg):
    print(f"[build_audio] {msg}")


# --------------------------------------------------------------------------
# Deterministic per-cue RNG
# --------------------------------------------------------------------------
def rng_for(*parts):
    key = "|".join(str(p) for p in parts)
    seed = zlib.crc32(key.encode("utf-8")) & 0xFFFFFFFF
    return np.random.default_rng(seed)


# --------------------------------------------------------------------------
# Basic DSP utilities
# --------------------------------------------------------------------------
def n_samples(dur):
    return max(1, int(round(dur * SR)))


def t_array(dur=None, n=None):
    if n is None:
        n = n_samples(dur)
    return np.arange(n) / SR


def fade_io(x, fade_in=0.002, fade_out=0.005):
    """Apply short linear fades to avoid clicks. x: (n,) or (n,2)."""
    n = x.shape[0]
    ni = min(n_samples(fade_in), n // 2 if n > 1 else 0)
    no = min(n_samples(fade_out), n // 2 if n > 1 else 0)
    if ni > 0:
        env = np.linspace(0.0, 1.0, ni)
        if x.ndim == 2:
            x[:ni] *= env[:, None]
        else:
            x[:ni] *= env
    if no > 0:
        env = np.linspace(1.0, 0.0, no)
        if x.ndim == 2:
            x[-no:] *= env[:, None]
        else:
            x[-no:] *= env
    return x


def to_stereo(x, pan=0.0, width=0.0, rng=None):
    """Mono (n,) -> stereo (n,2) with equal-power pan in [-1,1] and optional
    decorrelated widening (0..1)."""
    x = np.asarray(x, dtype=np.float64)
    theta = (pan + 1.0) * (np.pi / 4.0)  # 0..pi/2
    lg, rg = np.cos(theta), np.sin(theta)
    left = x * lg
    right = x * rg
    if width > 0:
        if rng is None:
            rng = np.random.default_rng(0)
        n = x.shape[0]
        # tiny sample delay + a hint of decorrelated noise for width
        d = max(1, int(0.0006 * SR))
        delayed = np.concatenate([np.zeros(d), x[:-d]]) if n > d else x
        left = left * (1 - width) + delayed * lg * width
        right = right * (1 - width) + x * rg * width
    return np.stack([left, right], axis=1)


def mono_dual(fn, n, rng):
    """Run a generator fn(n, rng)->mono twice with independent noise draws
    to get a naturally decorrelated stereo pair (used for wide ambiences)."""
    a = fn(n, rng)
    b = fn(n, rng)
    return np.stack([a, b], axis=1)


def db_rms_normalize(x, target_db):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-12
    return x * (DB(target_db) / rms)


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


# --------------------------------------------------------------------------
# Noise generators
# --------------------------------------------------------------------------
def white(n, rng):
    return rng.standard_normal(n)


def colored_noise(n, rng, exponent=1.0, min_hz=20.0):
    """exponent=0 white, 1 pink, 2 brown/red.

    Frequencies below min_hz are floored to min_hz before applying the
    1/f^exponent tilt. Without this floor, the near-DC FFT bins receive an
    enormous gain boost (dividing by an almost-zero frequency), which shows
    up as a slow drifting DC-like offset across the buffer -- especially
    visible for brown noise (exponent=2). Flooring keeps the spectral tilt
    audible while removing that drift/DC artifact.
    """
    w = rng.standard_normal(n)
    X = np.fft.rfft(w)
    freqs_hz = np.fft.rfftfreq(n, d=1.0 / SR)
    f = np.maximum(freqs_hz, min_hz)
    X = X / (f ** (exponent / 2.0))
    X[0] = 0.0
    y = np.fft.irfft(X, n)
    y = y - np.mean(y)
    y = y / (np.std(y) + 1e-12)
    return y


def pink(n, rng):
    return colored_noise(n, rng, 1.0)


def brown(n, rng):
    return colored_noise(n, rng, 2.0)


# --------------------------------------------------------------------------
# Filters
# --------------------------------------------------------------------------
def _sos(kind, cutoff, order=2):
    cutoff = np.clip(cutoff, 5, SR / 2 - 10)
    return sig.butter(order, cutoff, btype=kind, fs=SR, output="sos")


def lowpass(x, cutoff, order=2):
    return sig.sosfilt(_sos("low", cutoff, order), x)


def highpass(x, cutoff, order=2):
    return sig.sosfilt(_sos("high", cutoff, order), x)


def bandpass(x, lo, hi, order=2):
    lo = np.clip(lo, 5, SR / 2 - 20)
    hi = np.clip(hi, lo + 10, SR / 2 - 5)
    sos = sig.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return sig.sosfilt(sos, x)


def sweep_bandpass(x, center_env, q=4.0):
    """Time-varying bandpass using a chain of short-block filters following
    center_env (Hz per-sample array). Efficient block approach."""
    n = len(x)
    block = 512
    out = np.zeros(n)
    zi_state = None
    i = 0
    while i < n:
        j = min(n, i + block)
        c = float(np.mean(center_env[i:j]))
        bw = max(c / q, 10.0)
        try:
            y = bandpass(x[i:j], c - bw / 2, c + bw / 2, order=2)
        except Exception:
            y = x[i:j]
        out[i:j] = y
        i = j
    return out


def dc_block(x):
    return x - np.mean(x)


def remove_dc(x):
    if x.ndim == 2:
        return x - np.mean(x, axis=0, keepdims=True)
    return x - np.mean(x)


# --------------------------------------------------------------------------
# Envelopes
# --------------------------------------------------------------------------
def exp_decay(n, tau_s, start=1.0):
    t = t_array(n=n)
    return start * np.exp(-t / max(tau_s, 1e-4))


def attack_decay(n, attack_s, decay_s):
    na = max(1, min(n, n_samples(attack_s)))
    env = np.zeros(n)
    env[:na] = np.linspace(0, 1, na)
    rest = n - na
    if rest > 0:
        env[na:] = np.exp(-t_array(n=rest) / max(decay_s, 1e-4))
    return env


def hump(n, skew=0.5):
    """0..1..0 smooth hump across n samples, peak at skew (0..1)."""
    t = np.linspace(0, 1, n)
    peak = np.clip(skew, 0.02, 0.98)
    env = np.where(
        t < peak,
        0.5 - 0.5 * np.cos(np.pi * (t / peak)),
        0.5 + 0.5 * np.cos(np.pi * ((t - peak) / (1 - peak))),
    )
    return env


# --------------------------------------------------------------------------
# Oscillators
# --------------------------------------------------------------------------
def sine(n, freq):
    t = t_array(n=n)
    if np.isscalar(freq):
        return np.sin(2 * np.pi * freq * t)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(phase)


def saw(n, freq):
    t = t_array(n=n)
    if np.isscalar(freq):
        ph = (freq * t) % 1.0
    else:
        ph = (np.cumsum(freq) / SR) % 1.0
    return 2 * ph - 1


def square_wave(n, freq, duty=0.5):
    t = t_array(n=n)
    ph = (freq * t) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def detuned_cluster(n, base_freqs, voices=3, detune_cents=12, wave="saw", rng=None):
    """Sum of detuned oscillators per base frequency -> dark cluster texture."""
    if rng is None:
        rng = np.random.default_rng(0)
    out = np.zeros(n)
    osc = saw if wave == "saw" else sine
    for f0 in base_freqs:
        for v in range(voices):
            cents = rng.uniform(-detune_cents, detune_cents)
            f = f0 * (2 ** (cents / 1200.0))
            out += osc(n, f) / (voices * len(base_freqs))
    return out


def modal_resonator(n, freqs, decays, amps, jitter=0.0, rng=None):
    """Sum of decaying sinusoids -> metallic bell/ring."""
    if rng is None:
        rng = np.random.default_rng(0)
    t = t_array(n=n)
    out = np.zeros(n)
    for f, d, a in zip(freqs, decays, amps):
        fj = f * (1 + (rng.uniform(-jitter, jitter) if jitter else 0))
        out += a * np.sin(2 * np.pi * fj * t) * np.exp(-t / max(d, 1e-4))
    return out


# --------------------------------------------------------------------------
# Synthetic convolution reverb
# --------------------------------------------------------------------------
_IR_CACHE = {}


def _build_ir(kind):
    rng = np.random.default_rng(hash(kind) & 0xFFFFFFFF)
    if kind == "dry":
        n = n_samples(0.05)
        t = t_array(n=n)
        ir = np.exp(-t / 0.008) * rng.standard_normal(n) * 0.15
        ir[0] += 1.0
    elif kind == "metal_room":
        n = n_samples(0.9)
        t = t_array(n=n)
        tail = colored_noise(n, rng, 1.4) * np.exp(-t / 0.22)
        tail = bandpass(tail, 250, 6000, order=2)
        modes = modal_resonator(
            n,
            freqs=[118, 233, 410, 730, 1180, 1900],
            decays=[0.5, 0.42, 0.35, 0.28, 0.2, 0.15],
            amps=[0.35, 0.3, 0.22, 0.16, 0.1, 0.06],
        )
        ir = tail * 0.6 + modes * 0.5
        ir[0] += 1.0
    elif kind == "hangar":
        n = n_samples(2.4)
        t = t_array(n=n)
        # early reflections
        ir = np.zeros(n)
        ir[0] = 1.0
        for tap_t, amp in [(0.02, .5), (0.045, .4), (0.07, .32), (0.11, .25),
                            (0.16, .2), (0.22, .15)]:
            idx = n_samples(tap_t)
            if idx < n:
                ir[idx] += amp * (1 if rng.random() > 0.5 else -1)
        tail = colored_noise(n, rng, 1.0) * np.exp(-t / 0.75)
        tail = lowpass(tail, 5500)
        tail = highpass(tail, 80)
        ir += tail * 0.7
    elif kind == "outdoor":
        n = n_samples(0.35)
        t = t_array(n=n)
        ir = np.zeros(n)
        ir[0] = 1.0
        tail = colored_noise(n, rng, 1.8) * np.exp(-t / 0.09)
        tail = lowpass(tail, 3500)
        ir += tail * 0.35
    else:
        n = 1
        ir = np.array([1.0])
    # normalise by energy, not peak: a long noise tail normalised to peak 1 carries 30-40 dB of
    # gain through the convolution and wrecks the mix balance
    ir = ir / (np.sqrt(np.sum(ir ** 2)) + 1e-9)
    return ir


def get_ir(kind):
    if kind not in _IR_CACHE:
        _IR_CACHE[kind] = _build_ir(kind)
    return _IR_CACHE[kind]


def apply_reverb(stereo_x, kind, wet=0.35):
    if kind == "dry" or wet <= 0:
        return stereo_x
    ir = get_ir(kind)
    n = stereo_x.shape[0]
    out = np.zeros((n + len(ir) - 1, 2))
    for ch in range(2):
        wetsig = sig.fftconvolve(stereo_x[:, ch], ir, mode="full")
        drysig = np.zeros_like(wetsig)
        drysig[:n] = stereo_x[:, ch]
        out[:, ch] = drysig * (1 - wet) + wetsig * wet
    return out


# --------------------------------------------------------------------------
# Master buffer + placement
# --------------------------------------------------------------------------
def add_at(master, stereo_x, start_sample, gain=1.0):
    """Bounds-safe additive placement into the (N_TOTAL,2) master buffer."""
    n = stereo_x.shape[0]
    s0 = start_sample
    s1 = start_sample + n
    if s1 <= 0 or s0 >= N_TOTAL:
        return
    src0 = max(0, -s0)
    src1 = n - max(0, s1 - N_TOTAL)
    dst0 = max(0, s0)
    dst1 = dst0 + (src1 - src0)
    if src1 <= src0:
        return
    master[dst0:dst1] += stereo_x[src0:src1] * gain


# ==========================================================================
# CUE SYNTHESIS FUNCTIONS
# Each returns (stereo (n,2) float array, suggested_reverb_wet_override or None)
# Signature: fn(dur, rng, gain=1.0) -> stereo np.array
# `dur` is a hint (seconds); many types have sensible internal defaults.
# ==========================================================================

def _gun_transient(n, rng, crack_hp=1800, sub_freq=55, sub_tau=0.09,
                    noise_tau=0.055, crack_tau=0.02, sub_amt=1.0):
    t = t_array(n=n)
    # sharp crack transient (short highpassed noise burst)
    crack = highpass(rng.standard_normal(n), crack_hp)
    crack *= np.exp(-t / crack_tau)
    # broadband noise burst, slower decay
    body = colored_noise(n, rng, 0.6) * np.exp(-t / noise_tau)
    # low thump
    thump = np.sin(2 * np.pi * sub_freq * t) * np.exp(-t / sub_tau) * sub_amt
    thump += 0.5 * np.sin(2 * np.pi * sub_freq * 1.9 * t) * np.exp(-t / (sub_tau * 0.6)) * sub_amt
    out = crack * 0.9 + body * 0.8 + thump
    return out


def syn_ks23_shot(dur, rng, gain=1.0):
    n = n_samples(0.55)
    core = _gun_transient(n, rng, crack_hp=1200, sub_freq=48, sub_tau=0.16,
                           noise_tau=0.11, crack_tau=0.03, sub_amt=1.6)
    # metallic slap resonance baked in (room slap on top of convolution reverb)
    modes = modal_resonator(n, freqs=[95, 180, 340], decays=[0.22, 0.18, 0.12],
                             amps=[0.5, 0.3, 0.18], jitter=0.02, rng=rng)
    x = core + modes
    x = soft_clip(x * 1.15, 1.4)
    x = fade_io(x, 0.0005, 0.02)
    st = to_stereo(x, pan=rng.uniform(-0.15, 0.15), width=0.3, rng=rng)
    return st * 1.6 * gain


def syn_pump_rack(dur, rng, gain=1.0):
    total = n_samples(0.32)
    out = np.zeros(total)
    for i, t0 in enumerate([0.0, 0.15]):
        n = n_samples(0.09)
        t = t_array(n=n)
        clack = highpass(rng.standard_normal(n), 2500) * np.exp(-t / 0.012)
        ring = modal_resonator(n, freqs=[520, 890, 1450], decays=[0.05, 0.04, 0.03],
                                amps=[0.4, 0.25, 0.15], jitter=0.03, rng=rng)
        seg = fade_io(clack * 0.8 + ring, 0.0003, 0.05)
        s0 = n_samples(t0)
        end = min(total, s0 + n)
        out[s0:end] += seg[: end - s0]
    st = to_stereo(out, pan=rng.uniform(-0.1, 0.1), width=0.15, rng=rng)
    return st * 0.9 * gain


def _burst_of_shots(dur, rng, rpm, shot_fn, tinkles=True):
    interval = 60.0 / rpm
    nshots = max(2, int(round((dur if dur else interval * 5) / interval)))
    total_dur = nshots * interval + 0.4
    total = n_samples(total_dur)
    out = np.zeros(total)
    for i in range(nshots):
        jitter = rng.uniform(-0.004, 0.004)
        t0 = i * interval + jitter
        seg = shot_fn(rng)
        s0 = n_samples(max(0, t0))
        end = min(total, s0 + len(seg))
        if end > s0:
            out[s0:end] += seg[: end - s0]
    if tinkles:
        tail_start = n_samples(nshots * interval + 0.05)
        for k in range(rng.integers(3, 7)):
            tt0 = tail_start + n_samples(rng.uniform(0.0, 0.35))
            nt = n_samples(0.05)
            t = t_array(n=nt)
            click = highpass(rng.standard_normal(nt), 4500) * np.exp(-t / 0.02)
            click = modal_resonator(nt, freqs=[3200 * rng.uniform(0.8, 1.3)],
                                     decays=[0.02], amps=[0.3]) + click * 0.5
            end = min(total, tt0 + nt)
            if end > tt0:
                out[tt0:end] += click[: end - tt0] * 0.25
    return out


def syn_ak_burst(dur, rng, gain=1.0):
    def shot(r):
        n = n_samples(0.09)
        return _gun_transient(n, r, crack_hp=2200, sub_freq=90, sub_tau=0.045,
                               noise_tau=0.03, crack_tau=0.012, sub_amt=0.7)
    out = _burst_of_shots(dur, rng, rpm=700, shot_fn=shot)
    out = soft_clip(out * 1.1, 1.3)
    st = to_stereo(out, pan=rng.uniform(-0.2, 0.2), width=0.25, rng=rng)
    return fade_io(st, 0.0005, 0.03) * 1.3 * gain


def syn_ppsh_burst(dur, rng, gain=1.0):
    def shot(r):
        n = n_samples(0.1)
        return _gun_transient(n, r, crack_hp=1400, sub_freq=70, sub_tau=0.06,
                               noise_tau=0.045, crack_tau=0.018, sub_amt=0.9)
    out = _burst_of_shots(dur, rng, rpm=950, shot_fn=shot)
    out = soft_clip(out * 1.1, 1.3)
    st = to_stereo(out, pan=rng.uniform(-0.2, 0.2), width=0.25, rng=rng)
    return fade_io(st, 0.0005, 0.03) * 1.25 * gain


def syn_makarov_shot(dur, rng, gain=1.0):
    n = n_samples(0.25)
    x = _gun_transient(n, rng, crack_hp=1900, sub_freq=75, sub_tau=0.05,
                        noise_tau=0.04, crack_tau=0.014, sub_amt=0.8)
    x = soft_clip(x * 1.1, 1.3)
    st = to_stereo(fade_io(x, 0.0005, 0.03), pan=rng.uniform(-0.15, 0.15), width=0.2, rng=rng)
    return st * 1.2 * gain


def syn_flare_shot(dur, rng, gain=1.0):
    n = n_samples(0.9)
    t = t_array(n=n)
    pop = highpass(rng.standard_normal(n_samples(0.05)), 1500) * np.exp(-t_array(n=n_samples(0.05)) / 0.01)
    whoosh = bandpass(colored_noise(n, rng, 0.8), 500, 4000) * hump(n, 0.15)
    out = np.zeros(n)
    out[: len(pop)] += pop * 0.9
    out += whoosh * 0.5
    st = to_stereo(fade_io(out, 0.001, 0.15), pan=rng.uniform(-0.2, 0.2), width=0.3, rng=rng)
    return st * 0.9 * gain


def syn_grenade_pin(dur, rng, gain=1.0):
    n = n_samples(0.12)
    t = t_array(n=n)
    ping = modal_resonator(n, freqs=[2600, 3800], decays=[0.03, 0.02], amps=[0.5, 0.3], rng=rng)
    click = highpass(rng.standard_normal(n), 3000) * np.exp(-t / 0.008)
    out = fade_io(ping * 0.6 + click * 0.5, 0.0005, 0.04)
    st = to_stereo(out, pan=rng.uniform(-0.1, 0.1), width=0.1, rng=rng)
    return st * 0.4 * gain


def syn_explosion(dur, rng, gain=1.0):
    total_dur = dur if dur else 2.2
    n = n_samples(total_dur)
    t = t_array(n=n)
    boom = (np.sin(2 * np.pi * 42 * t) + 0.6 * np.sin(2 * np.pi * 63 * t)) * np.exp(-t / 0.5)
    crack = highpass(rng.standard_normal(n_samples(0.05)), 1000) * np.exp(-t_array(n=n_samples(0.05)) / 0.015)
    rumble = lowpass(brown(n, rng), 160) * np.exp(-t / (total_dur * 0.6))
    out = np.zeros(n)
    out += boom * 1.1
    out[: len(crack)] += crack * 1.2
    out += rumble * 0.9
    # debris crackle
    ncrackle = int(rng.integers(20, 40))
    for _ in range(ncrackle):
        tt = rng.uniform(0.05, min(total_dur - 0.02, total_dur * 0.9))
        s0 = n_samples(tt)
        nn = n_samples(0.012)
        seg = highpass(rng.standard_normal(nn), 2500) * np.exp(-t_array(n=nn) / 0.006)
        end = min(n, s0 + nn)
        if end > s0:
            out[s0:end] += seg[: end - s0] * rng.uniform(0.05, 0.18)
    out = soft_clip(out * 1.2, 1.5)
    st = to_stereo(fade_io(out, 0.001, 0.3), pan=rng.uniform(-0.1, 0.1), width=0.5, rng=rng)
    return st * 1.7 * gain


def syn_glass_break(dur, rng, gain=1.0):
    n = n_samples(0.6)
    t = t_array(n=n)
    burst = highpass(rng.standard_normal(n_samples(0.05)), 2500) * np.exp(-t_array(n=n_samples(0.05)) / 0.015)
    shards = modal_resonator(n, freqs=list(rng.uniform(1800, 6500, 6)),
                              decays=list(rng.uniform(0.05, 0.18, 6)),
                              amps=list(rng.uniform(0.1, 0.25, 6)), rng=rng)
    out = np.zeros(n)
    out[: len(burst)] += burst * 0.9
    out += shards
    # tinkling tail
    for _ in range(int(rng.integers(6, 14))):
        tt = rng.uniform(0.05, 0.55)
        s0 = n_samples(tt)
        nn = n_samples(0.04)
        seg = modal_resonator(nn, freqs=[rng.uniform(2500, 7000)], decays=[0.03], amps=[0.2])
        end = min(n, s0 + nn)
        if end > s0:
            out[s0:end] += seg[: end - s0]
    st = to_stereo(fade_io(out, 0.001, 0.1), pan=rng.uniform(-0.3, 0.3), width=0.4, rng=rng)
    return st * 0.9 * gain


def syn_metal_clang(dur, rng, gain=1.0):
    n = n_samples(1.1)
    t = t_array(n=n)
    hit = highpass(rng.standard_normal(n_samples(0.02)), 800) * np.exp(-t_array(n=n_samples(0.02)) / 0.006)
    modes = modal_resonator(n, freqs=[210, 340, 610, 980, 1550],
                             decays=[0.6, 0.5, 0.4, 0.3, 0.22],
                             amps=[0.4, 0.35, 0.25, 0.18, 0.12], jitter=0.02, rng=rng)
    out = np.zeros(n)
    out[: len(hit)] += hit
    out += modes
    st = to_stereo(fade_io(out, 0.001, 0.15), pan=rng.uniform(-0.3, 0.3), width=0.2, rng=rng)
    return st * 0.9 * gain


def syn_tank_burst(dur, rng, gain=1.0):
    n = n_samples(1.4)
    t = t_array(n=n)
    shatter = highpass(rng.standard_normal(n_samples(0.05)), 2000) * np.exp(-t_array(n=n_samples(0.05)) / 0.02)
    thump = np.sin(2 * np.pi * 55 * t) * np.exp(-t / 0.15)
    gurgle = bandpass(colored_noise(n, rng, 1.2), 300, 1800) * hump(n, 0.2)
    splash = bandpass(colored_noise(n, rng, 0.7), 600, 5000) * np.exp(-t / 0.4)
    out = np.zeros(n)
    out[: len(shatter)] += shatter
    out += thump * 0.8 + gurgle * 0.5 + splash * 0.4
    st = to_stereo(fade_io(out, 0.001, 0.2), pan=rng.uniform(-0.2, 0.2), width=0.4, rng=rng)
    return st * 1.0 * gain


def syn_liquid_splash(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 0.6)
    t = t_array(n=n)
    body = bandpass(colored_noise(n, rng, 0.9), 400, 4500) * hump(n, 0.1)
    droplets = np.zeros(n)
    for _ in range(int(rng.integers(6, 14))):
        tt = rng.uniform(0.05, max(0.1, (dur or 0.6) - 0.05))
        s0 = n_samples(tt)
        nn = n_samples(0.03)
        seg = bandpass(rng.standard_normal(nn), 1500, 6000) * np.exp(-t_array(n=nn) / 0.015)
        end = min(n, s0 + nn)
        if end > s0:
            droplets[s0:end] += seg[: end - s0]
    out = body * 0.7 + droplets * 0.5
    st = to_stereo(fade_io(out, 0.005, 0.1), pan=rng.uniform(-0.3, 0.3), width=0.3, rng=rng)
    return st * 0.6 * gain


def syn_impact(dur, rng, gain=1.0):
    n = n_samples(0.4)
    t = t_array(n=n)
    thump = np.sin(2 * np.pi * 75 * t) * np.exp(-t / 0.09)
    noise = lowpass(colored_noise(n, rng, 0.6), 2200) * np.exp(-t / 0.06)
    out = thump * 0.8 + noise * 0.7
    st = to_stereo(fade_io(out, 0.0008, 0.08), pan=rng.uniform(-0.2, 0.2), width=0.2, rng=rng)
    return st * 0.8 * gain


def syn_whoosh(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 0.7)
    t = t_array(n=n)
    up = rng.random() > 0.5
    center = np.linspace(300, 3200, n) if up else np.linspace(3200, 300, n)
    x = sweep_bandpass(colored_noise(n, rng, 0.7), center, q=1.4)
    x *= hump(n, 0.5)
    st = to_stereo(fade_io(x, 0.02, 0.05), pan=rng.uniform(-0.4, 0.4), width=0.5, rng=rng)
    return st * 0.6 * gain


def syn_music_hit(dur, rng, gain=1.0):
    n = n_samples(1.0)
    t = t_array(n=n)
    cluster = detuned_cluster(n, [55, 58.5, 77.8], voices=2, detune_cents=8, rng=rng)
    cluster = lowpass(cluster, 900) * np.exp(-t / 0.5)
    noise = highpass(rng.standard_normal(n_samples(0.03)), 2000) * np.exp(-t_array(n=n_samples(0.03)) / 0.01)
    out = np.zeros(n)
    out[: len(noise)] += noise * 0.5
    out += cluster
    st = to_stereo(fade_io(out, 0.001, 0.3), pan=0, width=0.3, rng=rng)
    return st * 0.9 * gain


def syn_stinger(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 1.6)
    t = t_array(n=n)
    cluster = detuned_cluster(n, [41.2, 43.7, 62.0, 87.3], voices=3, detune_cents=15, rng=rng)
    cluster = lowpass(cluster, 1400)
    env = attack_decay(n, 0.01, dur if dur else 1.3)
    burst = highpass(rng.standard_normal(n_samples(0.06)), 1500) * np.exp(-t_array(n=n_samples(0.06)) / 0.02)
    out = np.zeros(n)
    out[: len(burst)] += burst * 0.7
    out += cluster * env
    out = soft_clip(out * 1.1, 1.3)
    st = to_stereo(fade_io(out, 0.001, 0.2), pan=0, width=0.5, rng=rng)
    return st * 1.1 * gain


def syn_drone_swell(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 4.0)
    t = t_array(n=n)
    cluster = detuned_cluster(n, [36.7, 39.0, 55.0, 58.3], voices=4, detune_cents=18, rng=rng)
    cutoff = 150 + 1200 * hump(n, 0.75) ** 1.5
    out = np.zeros(n)
    block = 1024
    i = 0
    while i < n:
        j = min(n, i + block)
        c = float(np.mean(cutoff[i:j]))
        out[i:j] = lowpass(cluster[i:j], c)
        i = j
    env = hump(n, 0.7)
    out *= env
    st = to_stereo(fade_io(out, 0.05, 0.3), pan=0, width=0.6, rng=rng)
    return st * 0.5 * gain


def syn_shriek(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 1.4)
    t = t_array(n=n)
    f0 = 900
    bend = f0 * (1.6 - 0.9 * (t / (t[-1] + 1e-6)))
    voice1 = saw(n, bend)
    voice2 = sine(n, bend * 1.5)
    ring = np.sin(2 * np.pi * 35 * t)
    voice = (voice1 * 0.6 + voice2 * 0.4) * (0.6 + 0.4 * ring)
    noise = bandpass(colored_noise(n, rng, 0.5), 700, 5000)
    out = voice * 0.6 + noise * 0.5
    out = bandpass(out, 400, 6000, order=2)
    out = soft_clip(out * 2.2, 1.8)
    env = attack_decay(n, 0.03, (dur or 1.4) * 0.8)
    out *= env
    st = to_stereo(fade_io(out, 0.005, 0.15), pan=rng.uniform(-0.3, 0.3), width=0.4, rng=rng)
    return st * 0.85 * gain


def syn_growl(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 1.6)
    t = t_array(n=n)
    base = 70 + 8 * np.sin(2 * np.pi * 5.5 * t)
    sub = sine(n, base * 0.5) * 0.5
    formant_noise = colored_noise(n, rng, 0.8)
    lfo = 0.5 + 0.5 * sig.square(2 * np.pi * rng.uniform(12, 20) * t)
    granulated = formant_noise * (0.3 + 0.7 * lfo)
    granulated = bandpass(granulated, 90, 700)
    out = granulated * 0.7 + sub * 0.6
    out = lowpass(out, 1200)
    env = hump(n, 0.4)
    out *= env
    st = to_stereo(fade_io(out, 0.02, 0.1), pan=rng.uniform(-0.2, 0.2), width=0.25, rng=rng)
    return st * 0.7 * gain


def syn_gore_hit(dur, rng, gain=1.0):
    n = n_samples(0.5)
    t = t_array(n=n)
    squelch = lowpass(colored_noise(n, rng, 0.6), 900) * np.exp(-t / 0.09)
    thump = np.sin(2 * np.pi * 60 * t) * np.exp(-t / 0.06)
    out = squelch * 0.9 + thump * 0.7
    for _ in range(int(rng.integers(3, 7))):
        tt = rng.uniform(0.0, 0.3)
        s0 = n_samples(tt)
        nn = n_samples(0.025)
        seg = highpass(rng.standard_normal(nn), 1800) * np.exp(-t_array(n=nn) / 0.01)
        end = min(n, s0 + nn)
        if end > s0:
            out[s0:end] += seg[: end - s0] * 0.3
    st = to_stereo(fade_io(out, 0.001, 0.1), pan=rng.uniform(-0.2, 0.2), width=0.2, rng=rng)
    return st * 0.8 * gain


def syn_body_fall(dur, rng, gain=1.0):
    n = n_samples(0.5)
    t = t_array(n=n)
    thump = np.sin(2 * np.pi * 50 * t) * np.exp(-t / 0.13)
    noise = lowpass(colored_noise(n, rng, 0.9), 500) * np.exp(-t / 0.1)
    out = thump * 0.9 + noise * 0.6
    st = to_stereo(fade_io(out, 0.001, 0.15), pan=rng.uniform(-0.2, 0.2), width=0.2, rng=rng)
    return st * 0.75 * gain


def syn_door_slam(dur, rng, gain=1.0):
    n = n_samples(1.4)
    t = t_array(n=n)
    thump = np.sin(2 * np.pi * 65 * t) * np.exp(-t / 0.11)
    burst = highpass(rng.standard_normal(n_samples(0.03)), 700) * np.exp(-t_array(n=n_samples(0.03)) / 0.01)
    modes = modal_resonator(n, freqs=[150, 300, 540, 880], decays=[0.5, 0.4, 0.3, 0.2],
                             amps=[0.35, 0.25, 0.18, 0.1], jitter=0.02, rng=rng)
    out = np.zeros(n)
    out[: len(burst)] += burst
    out += thump * 0.9 + modes
    st = to_stereo(fade_io(out, 0.001, 0.2), pan=rng.uniform(-0.15, 0.15), width=0.2, rng=rng)
    return st * 1.1 * gain


def syn_bolt_lock(dur, rng, gain=1.0):
    n = n_samples(0.5)
    t = t_array(n=n)
    click = highpass(rng.standard_normal(n_samples(0.015)), 1600) * np.exp(-t_array(n=n_samples(0.015)) / 0.006)
    modes = modal_resonator(n, freqs=[420, 780, 1250], decays=[0.16, 0.12, 0.09],
                             amps=[0.4, 0.25, 0.15], jitter=0.02, rng=rng)
    out = np.zeros(n)
    out[: len(click)] += click
    out += modes
    st = to_stereo(fade_io(out, 0.0005, 0.08), pan=rng.uniform(-0.1, 0.1), width=0.15, rng=rng)
    return st * 0.75 * gain


def syn_door_grind(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 2.0)
    center = 250 + 180 * np.sin(2 * np.pi * 0.7 * t_array(n=n)) + 60 * rng.standard_normal(n).cumsum() / n
    center = np.clip(center, 100, 1200)
    x = sweep_bandpass(colored_noise(n, rng, 0.8), center, q=3.5)
    stick_slip = 0.6 + 0.4 * (rng.standard_normal(n).cumsum() / np.sqrt(n))
    stick_slip = np.clip(stick_slip, 0.1, 1.4)
    out = x * stick_slip
    out = lowpass(out, 3000)
    env = hump(n, 0.5) * 0.6 + 0.4
    out *= env
    st = to_stereo(fade_io(out, 0.05, 0.15), pan=rng.uniform(-0.2, 0.2), width=0.25, rng=rng)
    return st * 0.7 * gain


def syn_power_down(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 1.2)
    t = t_array(n=n)
    freq = np.linspace(180, 40, n)
    tone = sine(n, freq) * np.exp(-t / (0.5 * (dur or 1.2)))
    crackle = bandpass(rng.standard_normal(n), 1500, 5000) * np.exp(-t / 0.15) * 0.3
    hum = sine(n, 60) * np.linspace(0.4, 0.0, n)
    out = tone * 0.5 + crackle + hum * 0.3
    st = to_stereo(fade_io(out, 0.005, 0.2), pan=0, width=0.2, rng=rng)
    return st * 0.55 * gain


def syn_power_up(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 1.2)
    t = t_array(n=n)
    freq = np.linspace(40, 180, n)
    tone = sine(n, freq) * np.linspace(0.05, 0.6, n)
    hum = sine(n, 60) * np.linspace(0.0, 0.35, n)
    crackle = bandpass(rng.standard_normal(n), 1500, 5000) * np.linspace(0.0, 0.2, n)
    out = tone + hum + crackle
    st = to_stereo(fade_io(out, 0.02, 0.1), pan=0, width=0.2, rng=rng)
    return st * 0.55 * gain


def syn_light_flicker(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 0.6)
    gate = np.zeros(n)
    i = 0
    while i < n:
        on = rng.random() > 0.35
        seglen = n_samples(rng.uniform(0.01, 0.08))
        if on:
            gate[i:i + seglen] = 1.0
        i += seglen
    buzz = bandpass(colored_noise(n, rng, 0.4), 800, 4000)
    hum60 = sine(n, 120) * 0.3
    out = (buzz * 0.6 + hum60) * gate
    st = to_stereo(fade_io(out, 0.002, 0.02), pan=0, width=0.15, rng=rng)
    return st * 0.35 * gain


def syn_fluorescent_buzz(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 3.0)
    t = t_array(n=n)
    hum = sine(n, 120) + 0.4 * sine(n, 240) + 0.2 * sine(n, 360)
    noise = bandpass(colored_noise(n, rng, 0.6), 1500, 6000) * 0.15
    flick = 1.0 + 0.05 * rng.standard_normal(n)
    out = (hum * 0.15 + noise) * flick
    st = to_stereo(fade_io(out, 0.05, 0.05), pan=0, width=0.15, rng=rng)
    return st * 0.35 * gain


def syn_footsteps(dur, rng, gain=1.0):
    total = dur if dur else 3.0
    n = n_samples(total)
    out = np.zeros(n)
    step_int = rng.uniform(0.42, 0.58)
    tt = 0.0
    while tt < total - 0.05:
        s0 = n_samples(tt)
        nn = n_samples(0.16)
        t = t_array(n=nn)
        thud = np.sin(2 * np.pi * rng.uniform(60, 90) * t) * np.exp(-t / 0.05)
        crunch = lowpass(colored_noise(nn, rng, 0.7), 2500) * np.exp(-t / 0.04)
        seg = thud * 0.6 + crunch * 0.5
        end = min(n, s0 + nn)
        if end > s0:
            out[s0:end] += seg[: end - s0]
        tt += step_int * rng.uniform(0.9, 1.1)
    st = to_stereo(fade_io(out, 0.01, 0.05), pan=rng.uniform(-0.3, 0.3), width=0.2, rng=rng)
    return st * 0.5 * gain


def syn_heartbeat(dur, rng, gain=1.0):
    total = dur if dur else 4.0
    n = n_samples(total)
    out = np.zeros(n)
    bpm = rng.uniform(58, 78)
    beat_int = 60.0 / bpm
    tt = 0.0
    while tt < total - 0.1:
        for off, f, tau, amp in [(0.0, 55, 0.14, 1.0), (0.18, 48, 0.1, 0.6)]:
            s0 = n_samples(tt + off)
            nn = n_samples(0.2)
            t = t_array(n=nn)
            seg = np.sin(2 * np.pi * f * t) * np.exp(-t / tau) * amp
            seg = lowpass(seg, 180)
            end = min(n, s0 + nn)
            if end > s0:
                out[s0:end] += seg[: end - s0]
        tt += beat_int
    st = to_stereo(fade_io(out, 0.02, 0.1), pan=0, width=0.1, rng=rng)
    return st * 0.6 * gain


def syn_breath(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 1.8)
    x = bandpass(colored_noise(n, rng, 1.0), 250, 2200)
    env = hump(n, 0.4)
    out = x * env
    st = to_stereo(fade_io(out, 0.05, 0.1), pan=rng.uniform(-0.15, 0.15), width=0.15, rng=rng)
    return st * 0.3 * gain


def syn_engine_idle(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 3.0)
    t = t_array(n=n)
    f = 34 + 2 * np.sin(2 * np.pi * 3.1 * t)
    pulse = square_wave(n, f, duty=0.3)
    pulse = pulse - np.mean(pulse)  # duty != 0.5 has a DC component; strip it
    pulse = lowpass(pulse, 500)
    rumble = lowpass(brown(n, rng), 220) * 0.5
    out = pulse * 0.5 + rumble
    out += 0.05 * rng.standard_normal(n)
    st = to_stereo(fade_io(out, 0.1, 0.1), pan=0, width=0.3, rng=rng)
    return st * 0.45 * gain


def syn_engine_rev(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 1.5)
    freq = np.linspace(32, 75, n)
    pulse = square_wave(n, freq, duty=0.35)
    pulse = pulse - np.mean(pulse)  # duty != 0.5 has a DC component; strip it
    pulse = lowpass(pulse, 900)
    noise = bandpass(colored_noise(n, rng, 0.6), 150, 2500) * np.linspace(0.2, 0.6, n)
    out = pulse * 0.6 + noise * 0.4
    env = np.linspace(0.3, 1.0, n)
    out *= env
    st = to_stereo(fade_io(out, 0.02, 0.1), pan=0, width=0.3, rng=rng)
    return st * 0.55 * gain


def syn_wind_gust(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 2.5)
    body = pink(n, rng)
    body = lowpass(body, 1800)
    center = 500 + 700 * hump(n, 0.5)
    whistle = sweep_bandpass(colored_noise(n, rng, 0.4), center, q=6)
    env = hump(n, 0.45)
    out = body * 0.6 * (0.4 + 0.6 * env) + whistle * env * 0.4
    st = to_stereo(fade_io(out, 0.1, 0.3), pan=rng.uniform(-0.4, 0.4), width=0.5, rng=rng)
    return st * 0.4 * gain


def syn_radio_static(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 2.0)
    t = t_array(n=n)
    hiss = bandpass(colored_noise(n, rng, 0.3), 300, 3400)
    fade_lfo = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(0.2, 0.6) * t + rng.uniform(0, 6.28))
    heterodyne = sine(n, 900 + 500 * np.sin(2 * np.pi * 0.15 * t)) * 0.05
    crackle = np.zeros(n)
    for _ in range(int(rng.integers(4, 10) * (dur or 2.0))):
        tt = rng.uniform(0, dur or 2.0)
        s0 = n_samples(tt)
        nn = n_samples(0.006)
        end = min(n, s0 + nn)
        if end > s0:
            crackle[s0:end] += rng.standard_normal(end - s0) * 0.4
    out = hiss * (0.5 + 0.5 * fade_lfo) + heterodyne + crackle
    st = to_stereo(fade_io(out, 0.02, 0.05), pan=0, width=0.2, rng=rng)
    return st * 0.3 * gain


def syn_radio_signal(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 2.0)
    carrier = 700
    t = t_array(n=n)
    gate = np.zeros(n)
    i = 0
    pattern = [0.12, 0.06, 0.2, 0.06, 0.12, 0.16] * 4
    for dl in pattern:
        seglen = n_samples(dl)
        if i >= n:
            break
        is_on = pattern.index(dl) % 2 == 0
        if is_on:
            gate[i:i + seglen] = 1.0
        i += seglen
    tone = sine(n, carrier) * gate
    env = np.convolve(tone, np.ones(n_samples(0.005)) / n_samples(0.005), mode="same")
    static = bandpass(colored_noise(n, rng, 0.3), 300, 3000) * 0.08
    out = env * 0.6 + static
    st = to_stereo(fade_io(out, 0.02, 0.05), pan=0, width=0.15, rng=rng)
    return st * 0.35 * gain


def syn_morse(dur, rng, gain=1.0):
    n = n_samples(dur if dur else 2.0)
    carrier = 750
    unit = 0.08
    symbols = []
    total_u = 0
    max_u = (dur or 2.0) / unit
    while total_u < max_u - 3:
        s = rng.choice(["dit", "dah", "gap", "wgap"])
        symbols.append(s)
        total_u += {"dit": 1, "dah": 3, "gap": 1, "wgap": 3}[s]
    out = np.zeros(n)
    pos = 0.0
    for s in symbols:
        if s in ("dit", "dah"):
            dl = unit if s == "dit" else unit * 3
            s0 = n_samples(pos)
            nn = n_samples(dl)
            t = t_array(n=nn)
            seg = sine(nn, carrier) * attack_decay(nn, 0.005, dl)
            end = min(n, s0 + nn)
            if end > s0:
                out[s0:end] += seg[: end - s0]
            pos += dl
        else:
            pos += unit if s == "gap" else unit * 3
    st = to_stereo(fade_io(out, 0.01, 0.05), pan=0, width=0.1, rng=rng)
    return st * 0.3 * gain


def syn_typewriter_key(dur, rng, gain=1.0):
    n = n_samples(0.09)
    t = t_array(n=n)
    strike = highpass(rng.standard_normal(n), 2200) * np.exp(-t / 0.01)
    thock = np.sin(2 * np.pi * rng.uniform(280, 420) * t) * np.exp(-t / 0.02)
    out = strike * 0.7 + thock * 0.5
    st = to_stereo(fade_io(out, 0.0003, 0.03), pan=rng.uniform(-0.2, 0.2), width=0.1, rng=rng)
    return st * 0.5 * gain


CUE_SYNTH = {
    "typewriter_key": syn_typewriter_key,
    "radio_static": syn_radio_static,
    "radio_signal": syn_radio_signal,
    "morse": syn_morse,
    "engine_idle": syn_engine_idle,
    "engine_rev": syn_engine_rev,
    "wind_gust": syn_wind_gust,
    "door_grind": syn_door_grind,
    "door_slam": syn_door_slam,
    "bolt_lock": syn_bolt_lock,
    "power_down": syn_power_down,
    "power_up": syn_power_up,
    "light_flicker": syn_light_flicker,
    "fluorescent_buzz": syn_fluorescent_buzz,
    "footsteps": syn_footsteps,
    "heartbeat": syn_heartbeat,
    "breath": syn_breath,
    "stinger": syn_stinger,
    "drone_swell": syn_drone_swell,
    "shriek": syn_shriek,
    "growl": syn_growl,
    "gore_hit": syn_gore_hit,
    "body_fall": syn_body_fall,
    "ks23_shot": syn_ks23_shot,
    "pump_rack": syn_pump_rack,
    "ak_burst": syn_ak_burst,
    "ppsh_burst": syn_ppsh_burst,
    "makarov_shot": syn_makarov_shot,
    "flare_shot": syn_flare_shot,
    "grenade_pin": syn_grenade_pin,
    "explosion": syn_explosion,
    "glass_break": syn_glass_break,
    "metal_clang": syn_metal_clang,
    "tank_burst": syn_tank_burst,
    "liquid_splash": syn_liquid_splash,
    "impact": syn_impact,
    "whoosh": syn_whoosh,
    "music_hit": syn_music_hit,
}

# reverb wet amount per cue type (context-appropriate); default 0.3
CUE_REVERB_WET = {
    "typewriter_key": 0.08,
    "radio_static": 0.0,
    "radio_signal": 0.0,
    "morse": 0.0,
    "ks23_shot": 0.55,
    "ak_burst": 0.4,
    "ppsh_burst": 0.4,
    "makarov_shot": 0.35,
    "pump_rack": 0.25,
    "explosion": 0.5,
    "grenade_pin": 0.15,
    "flare_shot": 0.3,
    "shriek": 0.45,
    "growl": 0.35,
    "gore_hit": 0.1,
    "body_fall": 0.2,
    "door_slam": 0.4,
    "bolt_lock": 0.3,
    "door_grind": 0.2,
    "metal_clang": 0.45,
    "glass_break": 0.3,
    "tank_burst": 0.35,
    "liquid_splash": 0.15,
    "impact": 0.25,
    "whoosh": 0.15,
    "footsteps": 0.15,
    "heartbeat": 0.0,
    "breath": 0.0,
    "fluorescent_buzz": 0.05,
    "light_flicker": 0.0,
    "power_down": 0.1,
    "power_up": 0.1,
    "wind_gust": 0.0,
    "engine_idle": 0.1,
    "engine_rev": 0.15,
    "stinger": 0.3,
    "drone_swell": 0.2,
    "music_hit": 0.25,
}


# --------------------------------------------------------------------------
# Ambience beds
# --------------------------------------------------------------------------
def amb_blizzard(n, rng):
    def gen(nn, r):
        base = pink(nn, r)
        base = lowpass(base, 2200)
        base = highpass(base, 40)
        t = t_array(n=nn)
        gust_lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 0.045 * t + r.uniform(0, 6.28))
        gust_lfo += 0.25 * np.sin(2 * np.pi * 0.013 * t + r.uniform(0, 6.28))
        gust_lfo = np.clip(gust_lfo, 0.15, 1.3)
        center = 600 + 900 * np.clip(gust_lfo, 0, 1)
        whistle = sweep_bandpass(colored_noise(nn, r, 0.5), center, q=5) * 0.25
        return base * (0.5 + 0.6 * gust_lfo) + whistle * gust_lfo
    st = mono_dual(gen, n, rng)
    return db_rms_normalize(st, -27)


def amb_interior_hum(n, rng):
    def gen(nn, r):
        t = t_array(n=nn)
        hum = sine(nn, 60) * 0.5 + sine(nn, 120) * 0.25 + sine(nn, 180) * 0.1
        rumble = lowpass(brown(nn, r), 300) * 0.4
        flicker = 1.0 + 0.02 * r.standard_normal(nn)
        return (hum * 0.3 + rumble) * flicker
    st = mono_dual(gen, n, rng)
    return db_rms_normalize(st, -29)


def amb_interior_dead(n, rng):
    def gen(nn, r):
        t = t_array(n=nn)
        base = lowpass(pink(nn, r), 900) * 0.3
        out = base
        # sparse distant metallic groans / creaks
        pos = 0.0
        total = nn / SR
        while pos < total - 1.0:
            pos += r.uniform(3.0, 9.0)
            if pos >= total - 1.0:
                break
            s0 = int(pos * SR)
            gl = n_samples(r.uniform(0.8, 2.2))
            tt = t_array(n=gl)
            f = r.uniform(60, 160)
            groan = np.sin(2 * np.pi * f * tt + 0.6 * np.sin(2 * np.pi * 0.7 * tt)) * np.exp(-tt / (gl / SR * 0.6))
            groan = lowpass(groan, 500)
            groan *= hump(gl, 0.3) * 0.35
            end = min(nn, s0 + gl)
            if end > s0:
                out[s0:end] += groan[: end - s0]
        return out
    st = mono_dual(gen, n, rng)
    return db_rms_normalize(st, -29)


def amb_hangar(n, rng):
    def gen(nn, r):
        base = lowpass(pink(nn, r), 1500) * 0.35
        rumble = lowpass(brown(nn, r), 200) * 0.35
        t = t_array(n=nn)
        drip_out = np.zeros(nn)
        pos = 0.0
        total = nn / SR
        while pos < total - 0.5:
            pos += r.uniform(2.5, 6.0)
            if pos >= total - 0.5:
                break
            s0 = int(pos * SR)
            dl = n_samples(0.4)
            tt = t_array(n=dl)
            drip = modal_resonator(dl, freqs=[r.uniform(900, 2200)], decays=[0.3], amps=[0.15])
            end = min(nn, s0 + dl)
            if end > s0:
                drip_out[s0:end] += drip[: end - s0]
        return base + rumble + drip_out
    st = mono_dual(gen, n, rng)
    return db_rms_normalize(st, -26)


def amb_none(n, rng):
    return np.zeros((n, 2))


AMBIENCE_SYNTH = {
    "blizzard": amb_blizzard,
    "interior_hum": amb_interior_hum,
    "interior_dead": amb_interior_dead,
    "hangar": amb_hangar,
    "none": amb_none,
}


# --------------------------------------------------------------------------
# Score
# --------------------------------------------------------------------------
def build_score(shots):
    N = N_TOTAL
    t = np.arange(N) / SR
    score = np.zeros(N)
    rng = np.random.default_rng(20090909)

    shot_by_name = {s["name"]: s for s in shots}

    def env_window(t0, t1, a=1.5, r=1.5):
        """Smooth 0..1..0 envelope active between t0..t1 with attack/release."""
        e = np.zeros(N)
        i0, i1 = n_samples(t0), n_samples(t1)
        i0 = max(0, min(N, i0))
        i1 = max(0, min(N, i1))
        if i1 <= i0:
            return e
        na = min(n_samples(a), (i1 - i0) // 2 or 1)
        nr = min(n_samples(r), (i1 - i0) // 2 or 1)
        e[i0:i0 + na] = np.linspace(0, 1, na)
        e[i0 + na:i1 - nr] = 1.0
        e[i1 - nr:i1] = np.linspace(1, 0, nr)
        return e

    # ---- 1. low sub drone bed, present almost throughout ----
    sub = (np.sin(2 * np.pi * 34 * t) * 0.6 + np.sin(2 * np.pi * 51 * t) * 0.3)
    sub_lfo = 0.7 + 0.3 * np.sin(2 * np.pi * 0.05 * t + 0.4)
    sub_env = env_window(6, 144, a=4, r=2)
    score += sub * sub_lfo * sub_env * 0.5

    # ---- 2. detuned string-like cluster (tension sections) ----
    cluster = detuned_cluster(N, [55.0, 58.3, 82.4], voices=3, detune_cents=14, rng=rng)
    # slow-moving lowpass cutoff, generally darker at rest, opens for tension
    tension_env = (
        0.15 * env_window(24, 44)
        + 0.35 * env_window(44, 58)
        + 0.5 * env_window(58, 76)
        + 1.0 * env_window(76, 100, a=6, r=1)
        + 0.2 * env_window(100, 113)
        + 1.0 * env_window(113, 131, a=5, r=2)
        + 0.4 * env_window(131, 144, a=3, r=3)
    )
    cutoff = 90 + 1600 * np.clip(tension_env, 0, 1)
    cluster_f = np.zeros(N)
    block = 2048
    i = 0
    while i < N:
        j = min(N, i + block)
        c = float(np.mean(cutoff[i:j]))
        cluster_f[i:j] = lowpass(cluster[i:j], c)
        i = j
    score += cluster_f * tension_env * 0.35

    # ---- 3. pulsing low heartbeat-like motif (armory prep -> fight -> escape) ----
    def heartbeat_motif(t0, t1, bpm0, bpm1):
        i0, i1 = n_samples(t0), n_samples(t1)
        i0, i1 = max(0, i0), min(N, i1)
        if i1 <= i0:
            return
        span = (i1 - i0) / SR
        bpm_env = np.linspace(bpm0, bpm1, i1 - i0)
        pos = 0.0
        idx = 0
        while True:
            bpm = bpm_env[min(idx, len(bpm_env) - 1)]
            beat_int = 60.0 / bpm
            if pos >= span:
                break
            s0 = i0 + int(pos * SR)
            nn = n_samples(0.22)
            tt = t_array(n=nn)
            thump = np.sin(2 * np.pi * 46 * tt) * np.exp(-tt / 0.1)
            thump = lowpass(thump, 150)
            end = min(N, s0 + nn)
            if end > s0:
                score[s0:end] += thump[: end - s0] * 0.35
            pos += beat_int
            idx = int(pos * SR)

    heartbeat_motif(60, 76, 62, 78)     # armory tension building
    heartbeat_motif(76, 100, 82, 118)   # fight, accelerating
    heartbeat_motif(113, 131, 100, 132) # escape, frantic

    # ---- 4. dissonant swells into fight and escape ----
    def swell(t_peak, length, lowf, highf, amt=0.6):
        i0 = n_samples(max(0, t_peak - length))
        i1 = n_samples(t_peak)
        i0, i1 = max(0, i0), min(N, i1)
        if i1 <= i0:
            return
        nn = i1 - i0
        e = hump(nn, 0.92) ** 0.7
        c = np.linspace(lowf, highf, nn)
        raw = colored_noise(nn, rng, 0.9)
        block = 1024
        j = 0
        out = np.zeros(nn)
        while j < nn:
            k = min(nn, j + block)
            cc = float(np.mean(c[j:k]))
            out[j:k] = bandpass(raw[j:k], max(30, cc - 200), cc + 200)
            j = k
        score[i0:i1] += out * e * amt

    swell(76, 10, 60, 900)     # into the fight
    swell(113, 8, 80, 1100)    # into the escape

    # ---- 5. quiet eerie tone in the lab (100-113) ----
    lab_i0, lab_i1 = n_samples(100), n_samples(113)
    nn = lab_i1 - lab_i0
    if nn > 0:
        tt = t_array(n=nn)
        eerie = sine(nn, 1046.5) * 0.06 + sine(nn, 1975.5) * 0.03
        eerie *= (0.5 + 0.5 * np.sin(2 * np.pi * 0.08 * tt))
        # occasional soft unease blips
        blip_rng = np.random.default_rng(4242)
        for _ in range(4):
            bt = blip_rng.uniform(0.5, (nn / SR) - 0.5)
            s0 = n_samples(bt)
            bl = n_samples(0.4)
            btt = t_array(n=bl)
            blip = sine(bl, blip_rng.uniform(1500, 2600)) * np.exp(-btt / 0.2) * 0.08
            end = min(nn, s0 + bl)
            if end > s0:
                eerie[s0:end] += blip[: end - s0]
        score[lab_i0:lab_i1] += eerie * 0.6

    # ---- 6. silence for scare cuts ----
    def duck_silence(tc, half_width=0.35, depth=1.0):
        i0 = n_samples(max(0, tc - half_width))
        i1 = n_samples(min(FILM_DUR, tc + half_width))
        nn = i1 - i0
        if nn <= 0:
            return
        # quick dip to (1-depth) and back, cosine taper
        w = np.hanning(nn)
        duck = 1.0 - depth * w
        score[i0:i1] *= duck

    duck_silence(56.2, half_width=0.4, depth=0.95)
    duck_silence(111.2, half_width=0.4, depth=0.95)

    # ---- 7. final low boom + ringing tone on end title (144 s) ----
    boom_t0 = n_samples(144.0)
    boom_len = n_samples(min(6.0, FILM_DUR - 144.0))
    if boom_len > 0:
        tt = t_array(n=boom_len)
        boom = np.sin(2 * np.pi * 38 * tt) * np.exp(-tt / 1.3)
        ring = modal_resonator(boom_len, freqs=[220, 440.5, 661, 990], decays=[3.0, 2.4, 1.8, 1.2],
                                amps=[0.25, 0.15, 0.1, 0.06], rng=rng)
        seg = boom * 0.9 + ring
        seg *= attack_decay(boom_len, 0.02, 5.0)
        end = min(N, boom_t0 + boom_len)
        if end > boom_t0:
            # boosted: this is the film's final gesture and must read clearly
            # even though the master's peak normalization is set by the
            # loudest gunshot earlier in the film.
            score[boom_t0:end] += seg[: end - boom_t0] * 3.2

    score = fade_io(score, 0.5, 1.0)
    score_st = to_stereo(score, pan=0.0, width=0.35, rng=rng)
    return score_st


# --------------------------------------------------------------------------
# Main build
# --------------------------------------------------------------------------
def load_timeline():
    with open(TIMELINE_PATH) as f:
        data = json.load(f)
    return data["shots"]


def load_cues(shots, cues_dir):
    result = {}
    for s in shots:
        path = os.path.join(cues_dir, s["name"], "cues.json")
        if not os.path.isfile(path):
            result[s["name"]] = None
            continue
        try:
            with open(path) as f:
                data = json.load(f)
        except Exception as e:
            warn(f"failed to parse {path}: {e}; treating shot as ambience-only")
            result[s["name"]] = None
            continue
        result[s["name"]] = data
    return result


def build_ambience_track(shots, cues_by_shot):
    master = np.zeros((N_TOTAL, 2))
    overlap = 1.2
    for s in shots:
        name = s["name"]
        start, dur = s["start"], s["duration"]
        data = cues_by_shot.get(name)
        amb_type = "none"
        if data and "ambience" in data:
            amb_type = data["ambience"]
            if amb_type not in ALLOWED_AMBIENCE:
                warn(f"{name}: unknown ambience '{amb_type}', using 'none'")
                amb_type = "none"
        pad_after = min(overlap, s["duration"])
        bed_dur = dur + pad_after
        rng = rng_for("ambience", name)
        n = n_samples(bed_dur)
        bed = remove_dc(AMBIENCE_SYNTH[amb_type](n, rng))
        # crossfade edges (skip fade-in for first shot start=0)
        fi = 0.0 if start <= 0.0001 else overlap
        fo = overlap if (start + dur) < FILM_DUR - 0.01 else 0.3
        bed = fade_io(bed.copy(), fi, fo)
        add_at(master, bed, n_samples(start))
    return master


def build_cues_track(shots, cues_by_shot):
    master = np.zeros((N_TOTAL, 2))
    n_cues = 0
    n_missing_files = 0
    n_unknown = 0
    for s in shots:
        name = s["name"]
        start = s["start"]
        data = cues_by_shot.get(name)
        if data is None:
            n_missing_files += 1
            continue
        amb_type = data.get("ambience", "none")
        if amb_type not in ALLOWED_AMBIENCE:
            amb_type = "none"
        reverb_kind = REVERB_FOR_AMBIENCE[amb_type]
        cues = data.get("cues", [])
        for idx, cue in enumerate(cues):
            ctype = cue.get("type")
            if ctype not in ALLOWED_CUE_TYPES:
                warn(f"{name}: unknown cue type '{ctype}', skipping")
                n_unknown += 1
                continue
            if ctype not in CUE_SYNTH:
                warn(f"{name}: cue type '{ctype}' has no synth impl, skipping")
                n_unknown += 1
                continue
            t_local = float(cue.get("t", 0.0))
            gain = float(cue.get("gain", 1.0))
            dur = cue.get("dur")
            rng = rng_for("cue", name, ctype, idx, round(t_local * 1000))
            try:
                stereo_x = CUE_SYNTH[ctype](dur, rng, gain=gain)
                stereo_x = remove_dc(stereo_x)  # safety net against any DC bias in a synth fn
            except Exception as e:
                warn(f"{name}: failed to synth cue '{ctype}' at t={t_local}: {e}")
                continue
            wet = CUE_REVERB_WET.get(ctype, 0.3)
            try:
                stereo_x = apply_reverb(stereo_x, reverb_kind, wet=wet)
            except Exception as e:
                warn(f"{name}: reverb failed for '{ctype}': {e}")
            global_sample = n_samples(start + t_local)
            add_at(master, stereo_x, global_sample)
            n_cues += 1
    info(f"placed {n_cues} cues, {n_missing_files} shots had no cues.json "
         f"(ambience+score only), {n_unknown} unknown/skipped cue entries")
    return master


# (start, end) seconds of total silence after the corridor face reveal and the lab tank burst
SILENCE_CUTS = [(56.58, 57.9), (111.25, 112.9)]


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


def limiter(master, target_db=-1.0, attack_ms=1.5, release_ms=120.0):
    """Look-ahead peak limiter: turns down only the samples that would exceed the ceiling,
    with a fast attack and slow release, so quiet passages keep their level."""
    ceil = DB(target_db)
    level = np.max(np.abs(master), axis=1)
    need = np.minimum(1.0, ceil / (level + 1e-12))           # instantaneous gain required
    la = max(1, int(SR * attack_ms / 1000))
    # look-ahead: gain must already be down when the peak arrives -> running min over the next `la` samples
    from scipy.ndimage import minimum_filter1d
    need = minimum_filter1d(need, size=2 * la + 1, mode="nearest")
    # smooth: instant attack (take min), exponential release
    rel = np.exp(-1.0 / (SR * release_ms / 1000))
    g = np.empty_like(need)
    cur = 1.0
    for i in range(len(need)):                               # simple one-pole release
        cur = need[i] if need[i] < cur else rel * cur + (1 - rel) * need[i]
        g[i] = cur
    out = master * g[:, None]
    return np.clip(soft_clip(out / ceil, 1.2) * ceil, -ceil, ceil)


def analyze(x, label):
    peak = np.max(np.abs(x))
    rms = np.sqrt(np.mean(x ** 2))
    peak_db = 20 * np.log10(peak + 1e-12)
    rms_db = 20 * np.log10(rms + 1e-12)
    info(f"{label}: peak={peak_db:.2f} dBFS  rms={rms_db:.2f} dBFS  "
         f"len={x.shape[0] / SR:.2f}s  dc={np.mean(x):.5f}")


def spectral_centroid(x_mono, sr=SR):
    X = np.abs(np.fft.rfft(x_mono * np.hanning(len(x_mono))))
    freqs = np.fft.rfftfreq(len(x_mono), 1 / sr)
    if X.sum() == 0:
        return 0.0
    return float(np.sum(freqs * X) / np.sum(X))


def run_self_test():
    os.makedirs(TEST_DIR, exist_ok=True)
    info("== self-test: rendering one example of every cue type ==")
    for name, fn in CUE_SYNTH.items():
        rng = rng_for("selftest", name)
        try:
            st = fn(1.0, rng, gain=1.0)
        except Exception as e:
            warn(f"self-test failed for {name}: {e}")
            continue
        st = np.nan_to_num(st)
        peak = np.max(np.abs(st))
        rms = np.sqrt(np.mean(st ** 2))
        centroid = spectral_centroid(st.mean(axis=1))
        dur_s = st.shape[0] / SR
        dc = np.mean(st)
        clip = peak > 0.999
        info(f"  {name:16s} dur={dur_s:6.3f}s peak={peak:6.3f} rms={rms:7.4f} "
             f"centroid={centroid:7.1f}Hz dc={dc:+.5f} {'CLIP!' if clip else ''}")
        # normalize to avoid clipping the test file itself
        safe = st / max(peak, 1e-6) * 0.9
        pcm = np.clip(safe, -1, 1)
        wavfile.write(os.path.join(TEST_DIR, f"{name}.wav"), SR, (pcm * 32767).astype(np.int16))

    info("== self-test: ambience beds (4 s each) ==")
    for name, fn in AMBIENCE_SYNTH.items():
        rng = rng_for("selftest_amb", name)
        n = n_samples(4.0)
        st = fn(n, rng)
        st = np.nan_to_num(st)
        peak = np.max(np.abs(st))
        rms = np.sqrt(np.mean(st ** 2))
        rms_db = 20 * np.log10(rms + 1e-12)
        info(f"  amb:{name:16s} peak={peak:6.3f} rms_db={rms_db:6.2f}")
        safe = st / max(peak, 1e-6) * 0.9 if peak > 0 else st
        pcm = np.clip(safe, -1, 1)
        wavfile.write(os.path.join(TEST_DIR, f"amb_{name}.wav"), SR, (pcm * 32767).astype(np.int16))

    info("== self-test: score (full 146 s) ==")
    shots = load_timeline()
    score = build_score(shots)
    analyze(score, "score")
    peak = np.max(np.abs(score))
    safe = score / max(peak, 1e-6) * 0.9
    wavfile.write(os.path.join(TEST_DIR, "score_full.wav"), SR, (np.clip(safe, -1, 1) * 32767).astype(np.int16))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true", help="also render build/audio_tests/*.wav")
    ap.add_argument("--use-test-cues", action="store_true", help="read build/test_cues/ instead of shots/")
    args = ap.parse_args()

    if args.self_test:
        run_self_test()

    shots = load_timeline()
    cues_dir = TEST_CUES_DIR if args.use_test_cues else SHOTS_DIR
    info(f"reading cues from {cues_dir}")
    cues_by_shot = load_cues(shots, cues_dir)

    info("building ambience beds...")
    ambience = build_ambience_track(shots, cues_by_shot)
    analyze(ambience, "ambience track")

    info("building score...")
    score = build_score(shots)
    analyze(score, "score track")

    info("building cues...")
    cues_track = build_cues_track(shots, cues_by_shot)
    analyze(cues_track, "cues track")

    info("mixing...")
    # bus gain staging: set each bus to a target loudness before summing, then only the
    # transients that exceed the ceiling get limited
    ambience = ambience * DB(-33.0 - rms_db(ambience))
    score = score * DB(-30.0 - rms_db(score))
    cues_track = cues_track * DB(-20.0 - rms_db(cues_track))
    master = ambience + score + cues_track
    master = remove_dc(master)
    master = limiter(master, target_db=-1.0)
    master = np.nan_to_num(master)
    # hard cuts to silence where the picture cuts to black after a scare (everything, tails included)
    for (a, b) in SILENCE_CUTS:
        env = np.ones(N_TOTAL)
        i0, i1 = n_samples(a), n_samples(b)
        f0, f1 = n_samples(0.012), n_samples(0.35)
        env[i0:i1] = 0.0
        env[i0:i0 + f0] = np.linspace(1, 0, f0)[: len(env[i0:i0 + f0])]
        env[i1 - f1:i1] = np.linspace(0, 1, f1)
        master *= env[:, None]

    assert master.shape[0] == N_TOTAL, f"length mismatch: {master.shape[0]} != {N_TOTAL}"

    analyze(master, "FINAL MASTER")

    os.makedirs(os.path.dirname(OUT_WAV), exist_ok=True)
    pcm = np.clip(master, -1, 1)
    pcm16 = (pcm * 32767).astype(np.int16)
    wavfile.write(OUT_WAV, SR, pcm16)
    info(f"wrote {OUT_WAV} ({N_TOTAL} samples / {N_TOTAL / SR:.3f}s @ {SR} Hz stereo)")


if __name__ == "__main__":
    main()
