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
			foreignClasses: [Point, foo.Foo, Bar],
		});
		
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