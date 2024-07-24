package;

@:wren.foreign
class Point {
	public function new() {}
	
	@:wren.foreign
	public function instanceMethod(i:Int, f:Float, s:String, b:Bool) {
		trace('Point Instance: $i, $f, $s, $b');
		return '$i';
	}
	
	@:wren.foreign
	public static function staticMethod(s:String) {
		trace('Point Static: $s');
	}
}