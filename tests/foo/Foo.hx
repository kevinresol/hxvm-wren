package foo;

@:wren.foreign
class Foo {
	public function new() {}
	
	@:wren.foreign
	public function test() {
		return 'Foo#test';
	}
}