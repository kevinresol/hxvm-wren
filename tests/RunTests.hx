package ;

import tink.unit.*;
import tink.testrunner.*;
import bar.Bar;

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
			loadModuleFn: (_, name) -> 'class $name { static name { "Module: $name" } }',
			foreignClasses: [Point, foo.Foo, Bar],
		});
		asserts.assert(wren.interpret('main', CODE) == WREN_RESULT_SUCCESS);
		
		wren.ensureSlots(1);
		wren.getVariable("main", "Main", 0);
		final mainClass = wren.getSlotHandle(0);
		final testPointStatic = wren.makeCallHandle("testPointStatic()");
		final testPointInstance = wren.makeCallHandle("testPointInstance()");
		
		wren.ensureSlots(1);
		wren.setSlotHandle(0, mainClass);
		asserts.assert(wren.call(testPointStatic) == WREN_RESULT_SUCCESS);
		
		wren.ensureSlots(1);
		wren.setSlotHandle(0, mainClass);
		asserts.assert(wren.call(testPointInstance) == WREN_RESULT_SUCCESS);
		// asserts.assert(wren.getSlotString(0) == 'Point Instance: 1, 2, foo, true');
		
		wren.free();
		
		return asserts.done();
	}
}

final CODE = '
class Main {
	static testPointStatic() {
		Point.staticMethod()
	}
		
	static testPointInstance() {
		var point = Point.new()
		var result = point.instanceMethod(1, 2.0, "foo", true)
		System.print("result in vm: %(result)")
	}
}
	
foreign class Point {
	construct new() {}
	foreign instanceMethod(i, f, s, b)
	foreign static staticMethod()
}
';