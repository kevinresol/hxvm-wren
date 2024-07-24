package;

@:wren.foreign('main', 'Point')
class Point {
	public function new() {}
	
	@:wren.foreign
	public function instanceMethod(i:Int, f:Float, s:String, b:Bool) {
		trace('Point Instance: $i, $f, $s, $b');
		return 'Point Instance: $i, $f, $s, $b';
	}
	
	@:wren.foreign
	public static function staticMethod() {
		trace('Point Static');
	}
}