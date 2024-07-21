package ;

import tink.unit.*;
import tink.testrunner.*;
// import deepequal.DeepEqual.*;

using tink.CoreApi;

@:asserts
class RunTests {

	static function main() {
		Runner.run(TestBatch.make([
			new RunTests(),
		])).handle(Runner.exit);
	}
	
	var instance:vm.wren.Wren;
	
	function new() {}
	
	@:before
	public function before() {
		trace('before');
		instance = new vm.wren.Wren();
		trace(instance);
		return Noise;
	}
	
	// @:after
	// public function after() {
	// 	cpp.vm.Gc.run(true);
	// 	instance = null;
	// 	return Noise;
	// }
	
	public function staticField() {
		instance.interpret('main', CODE);
		final clazz = instance.getClassHandle("main", "Call");
		final method = instance.getMethodHandle("value");
		asserts.assert(method.call(clazz) == 'bar');
		
		return asserts.done();
	}
	
	public function staticGetterSetter() {
		instance.interpret('main', CODE);
		final clazz = instance.getClassHandle("main", "Call");
		final getter = instance.getMethodHandle("getter");
		final setter = instance.getMethodHandle("setter=(_)");
		
		asserts.assert(getter.call(clazz) == null);
		setter.call(clazz, 'foo');
		asserts.assert(getter.call(clazz) == 'foo');
		
		return asserts.done();
	}
	
	public function noParams() {
		instance.interpret('main', CODE);
		final clazz = instance.getClassHandle("main", "Call");
		final method = instance.getMethodHandle("zero()");
		asserts.assert(method.call(clazz) == 'foo');
		
		return asserts.done();
	}
	
	public function oneParam() {
		instance.interpret('main', CODE);
		final clazz = instance.getClassHandle("main", "Call");
		final method = instance.getMethodHandle("one(_)");
		asserts.assert(method.call(clazz, 42) == 42);
		asserts.assert(method.call(clazz, 4.2) == 4.2);
		asserts.assert(method.call(clazz, true) == true);
		asserts.assert(method.call(clazz, false) == false);
		asserts.assert(method.call(clazz, null) == null);
		asserts.assert(method.call(clazz, 'foobar') == 'foobar');
		
		return asserts.done();
	}
	
}

final CODE = '
class Call {
	static value { "bar" }

	static getter {
		return __value
	}

	static setter=(v) {
		__value = v
	}

	static zero() {
		return "foo"
	}

	static one(one) {
		return one
	}

}
';