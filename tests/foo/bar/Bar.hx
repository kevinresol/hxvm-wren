package foo.bar;

@:wren.foreign
class Bar {
	public function new() {}
	
	@:wren.foreign
	public function test() {
		return 'Bar#test';
	}
}