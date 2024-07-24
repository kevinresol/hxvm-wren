package ;

import tink.unit.*;
import tink.testrunner.*;
import foo.bar.Bar;

using tink.CoreApi;

@:asserts
class RunTests {

	static function main() {
		Runner.run(TestBatch.make([
			new RunTests(),
		])).handle(Runner.exit);
	}
	
	function new() {}
	
	
	public function foreign() {
		final wren = vm.wren.Wren.make({
			writeFn: (_, v) -> Sys.print(v),
			errorFn: (_, type, module, line, message) -> Sys.println('[$module:$line] $message'),
			loadModuleFn: (_, name) -> CODE[name],
			foreignClasses: [Point, foo.Foo, Bar],
		});
		asserts.assert(wren.interpret('main', CODE['main']) == WREN_RESULT_SUCCESS);
		
		wren.ensureSlots(1);
		wren.getVariable("main", "Main", 0);
		final mainClass = wren.getSlotHandle(0);
		final testPointStatic = wren.makeCallHandle("testPointStatic()");
		final testPointInstance = wren.makeCallHandle("testPointInstance()");
		final testFooInstance = wren.makeCallHandle("testFooInstance()");
		final testBarInstance = wren.makeCallHandle("testBarInstance()");
		
		wren.ensureSlots(1);
		wren.setSlotHandle(0, mainClass);
		asserts.assert(wren.call(testPointStatic) == WREN_RESULT_SUCCESS);
		
		wren.ensureSlots(1);
		wren.setSlotHandle(0, mainClass);
		asserts.assert(wren.call(testPointInstance) == WREN_RESULT_SUCCESS);
		
		wren.ensureSlots(1);
		wren.setSlotHandle(0, mainClass);
		asserts.assert(wren.call(testFooInstance) == WREN_RESULT_SUCCESS);
		asserts.assert(wren.getSlotString(0) == 'got: Foo#test');
		
		wren.ensureSlots(1);
		wren.setSlotHandle(0, mainClass);
		asserts.assert(wren.call(testBarInstance) == WREN_RESULT_SUCCESS);
		asserts.assert(wren.getSlotString(0) == 'got: Bar#test');
		
		wren.releaseHandle(mainClass);
		wren.releaseHandle(testPointStatic);
		wren.releaseHandle(testPointInstance);
		wren.releaseHandle(testFooInstance);
		wren.releaseHandle(testBarInstance);
		
		wren.free();
		
		return asserts.done();
	}
}

final CODE = [
	'main' => '
		import "foo" for Foo
		import "foo/bar" for Bar
		
		class Main {
			static testPointStatic() {
				Point.staticMethod()
			}
				
			static testPointInstance() {
				var point = Point.new(42)
				var result = point.instanceMethod(1, 2.0, "foo", true)
				System.print("result in vm: %(result)")
			}
				
			static testFooInstance() {
				var foo = Foo.new()
				return "got: %(foo.test())"
			}
			static testBarInstance() {
				var bar = Bar.new()
				return "got: %(bar.test())"
			}
		}
			
		foreign class Point {
			construct new(m) {}
			foreign instanceMethod(i, f, s, b)
			foreign static staticMethod()
		}
	',
	'foo' => '
		foreign class Foo {
			construct new() {}
			foreign test()
		}
	',
	'foo/bar' => '
		foreign class Bar {
			construct new() {}
			foreign test()
		}
	',

];
