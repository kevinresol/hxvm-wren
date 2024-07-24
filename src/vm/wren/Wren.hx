package vm.wren;

class Wren {
	public static macro function make(options:haxe.macro.Expr):haxe.macro.Expr;
}

typedef WrenOptions = {
	writeFn:(vm:wren.WrenVM, text:String)->Void,
	errorFn:(vm:wren.WrenVM, type:wren.WrenErrorType, module:String, line:Int, message:String)->Void,
	loadModuleFn:(vm:wren.WrenVM, module:String)->String,
}