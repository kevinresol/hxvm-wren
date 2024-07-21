package vm.wren;

import cpp.Callable;
import wren.Wren.WrenInterpretResult;
import wren.Wren.*;
import haxe.Rest;

class Wren {
	final vm:wren.WrenVM;
	var destroyed:Bool = false;
	
	public function new() {
		vm = newVM();
		cpp.vm.Gc.setFinalizer(this, Callable.fromStaticFunction(finalize));
	}
	
	public inline function interpret(module:String, script:String):WrenInterpretResult {
		var v =  wren.Wren.interpret(vm, module, script);
		return v;
	}
	
	public inline function getClassHandle(module:String, name:String):ObjectHandle {
		ensureSlots(vm, 1);
		getVariable(vm, module, name, 0);
		return new ObjectHandle(vm, getSlotHandle(vm, 0));
	}
	
	public inline function getMethodHandle(signature:String):CallHandle {
		final handle = makeCallHandle(vm, signature);
		trace(signature, handle);
		return new CallHandle(vm, handle);
	}
	
	public inline function destroy() {
		if(!destroyed) {
			destroyed = true;
			freeVM(vm);
		}
	}
	
	public static function finalize(vm:Wren) {
		vm.destroy();
	}
	
}

class Handle {
	public final vm:wren.WrenVM;
	public final handle:wren.WrenHandle;
	var released:Bool = false;
	
	public function new(vm:wren.WrenVM, handle:wren.WrenHandle) {
		this.vm = vm;
		this.handle = handle;
		cpp.vm.Gc.setFinalizer(this, Callable.fromStaticFunction(finalize));
	}
	
	public inline function release() {
		if(!released) {
			released = true;
			releaseHandle(vm, handle);
		}
	}
	
	public static function finalize(handle:Handle) {
		handle.release();
	}
	
}

@:forward(release)
abstract ObjectHandle(Handle) from Handle {
	public inline function new(vm, handle) {
		this = new Handle(vm, handle);
	}
	
	@:to
	public inline function toHandle():wren.WrenHandle {
		return this.handle;
	}
}

@:forward(release)
abstract CallHandle(Handle) from Handle {
	public inline function new(vm, method) {
		this = new Handle(vm, method);
	}
	
	public inline function call(obj:wren.WrenHandle, args:Rest<Dynamic>):Dynamic {
		ensureSlots(this.vm, 1 + args.length);
		setSlotHandle(this.vm, 0, obj);
		for(i => arg in args) {
			switch Type.typeof(arg) {
				case TNull: setSlotNull(this.vm, 1 + i);
				case TInt: setSlotDouble(this.vm, 1 + i, arg);
				case TFloat: setSlotDouble(this.vm, 1 + i, arg);
				case TClass(String): setSlotString(this.vm, 1 + i, arg);
				case TBool: setSlotBool(this.vm, 1 + i, arg);
				// case TObject: setSlotHandle(vm, 1 + i, arg);
				case _: throw "Unsupported argument type";
			}
		}
		
		wren.Wren.call(this.vm, this.handle);
		
		return
			if (getSlotCount(this.vm) > 0) 
				switch getSlotType(this.vm, 0) {
					case WREN_TYPE_NULL: null;
					case WREN_TYPE_BOOL: getSlotBool(this.vm, 0);
					case WREN_TYPE_NUM: getSlotDouble(this.vm, 0);
					case WREN_TYPE_STRING: getSlotString(this.vm, 0);
					// case WREN_TYPE_HANDLE: getSlotHandle(vm, 0);
					case v: throw 'Unsupported return type $v';
				}
			else
				null;
	}
}