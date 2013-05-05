function Qux(a) {
  this.a = a;
}

Qux.prototype.add = function (val) {
  this.a += val;
};