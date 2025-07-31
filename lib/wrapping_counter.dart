class WrappingCounter {
  int _value;
  final int max;

  WrappingCounter(this.max, [this._value = 0]);

  int get value => _value;

  void increment() {
    _value = (_value + 1) % (max + 1);
  }
}
