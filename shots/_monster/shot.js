// t in [0,1): cam0 face, [1,2): cam1 full body idle, [2,3): cam1 running, [3,4): side run
export default {
  duration: 4,
  params: t => { const c = Math.floor(t); return [c === 3 ? 2 : Math.min(c, 1), c <= 1 ? 0.5 : 0, c===0?0.3:0.3, c >= 2 ? 1 : 0]; },
  post: t => ({ bar: 0.12 }),
};
