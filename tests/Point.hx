package;

@:wren.foreign('main', 'Point')
class Point {
	final m:Int;
	
	public function new(m:Int) {
		this.m = m;
	}
	
	@:wren.foreign
	public function instanceMethod(i:Int, f:Float, s:String, b:Bool) {
		trace('Point Instance: $m, $i, $f, $s, $b');
		return 'Point Instance: $m, $i, $f, $s, $b';
	}
	
	@:wren.foreign
	public static function staticMethod() {
		trace('Point Static');
	}
}