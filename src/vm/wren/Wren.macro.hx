package vm.wren;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

using StringTools;
using tink.MacroApi;

class Wren {
	public static macro function make(options:Expr):Expr {
		
		
		createBindingClasses(options);
		
		return macro wren.WrenVM.make({
			writeFn: (_, v) -> Sys.print(v),
			errorFn: (_, type, module, line, message) -> Sys.println('Error: $type $module $line $message'),
			loadModuleFn: (_, name) -> 'class $name { static name { "Module: $name" } }',
			bindForeignMethodFn: (vm, module, className, isStatic, signature) -> {
				return switch [module, className, isStatic, signature] {
					// case ['main', 'Call', true, 'add(_,_)']: cpp.Callable.fromStaticFunction(add);
					// case ['main', 'Point', false, 'print()']: cpp.Callable.fromStaticFunction(instance);
					case _: null;
				}
			},
			bindForeignClassFn:(__vm, module, className) -> {
				switch [module, className] {
					case ['main', 'Point']:
						return wren.WrenForeignClassMethods.make({
							allocate: cpp.Callable.fromStaticFunction(vm.wren.WrenForeignBinding_Point.__allocate),
							finalize: cpp.Callable.fromStaticFunction(vm.wren.WrenForeignBinding_Point.__finalize),
						});
						case _: /* no-op */
							return wren.WrenForeignClassMethods.init();
					}
			}
		});
	}
	
	static function createBindingClasses(options:Expr) {
		
		switch options {
			case macro {foreignClasses: $foreignClasses}:
				switch foreignClasses {
					case {expr: EArrayDecl(foreignClassesExprs)}:
						for(classExpr in foreignClassesExprs) {
							final type = Context.getType(classExpr.toString());
							final ct = type.toComplex();
							final tp = switch ct {
								case TPath(v): v;
								case _: throw 'Expected TypePath';
							}
							final pos = type.getPosition().sure();
							final meta = type.getMeta()[0];
							final id = type.getID();
							
							if(meta.has(':wren.foreign')) {
								final fields:Array<Field> = [
									{
										pos: pos,
										name: '__allocate',
										access: [APublic, AStatic],
										kind: FFun({
											args: [{name: '__vm', type: macro:cpp.Star<wren.native.WrenVM>}],
											ret: macro:Void,
											expr: macro {
												final __vm:wren.WrenVM = __vm;
												final inst = new $tp();
												__vm.setSlotNewForeignDynamic(0, 0, inst);
											}
										}),
									},
									{
										pos: pos,
										name: '__finalize',
										access: [APublic, AStatic],
										kind: FFun({
											args: [{name: 'ptr', type: macro:cpp.Star<cpp.Void>}],
											ret: macro:Void,
											expr: macro {
												wren.native.Wren.unroot(ptr);
											},
										}),
									}
								];
								
								for(field in type.getFields().sure()) {
									switch field.type.reduce() {
										case TFun(args, ret):
											fields.push(createBindingFunctionField(
												[macro final __inst:cpp.Star<$ct> = cast __vm.getSlotForeign(0)],
												macro __inst,
												field.name,
												args,
												ret,
												field.pos
											));
										case v:
											trace(v);
									}
								}
								
								for(field in type.getStatics().sure()) {
									switch field.type.reduce() {
										case TFun(args, ret):
											fields.push(createBindingFunctionField(
												[],
												macro $p{id.split('.')},
												field.name,
												args,
												ret,
												field.pos
											));
										case v:
											trace(v);
									}
								}
								
								
								final pos = type.getPosition().sure();
								final def:TypeDefinition = {
									pos: pos,
									pack: ['vm', 'wren'],
									name: 'WrenForeignBinding_${type.getID().replace('.', '_')}',
									kind: TDClass(null, [], false, true),
									fields: fields,
								}
								trace(new haxe.macro.Printer().printTypeDefinition(def));
								Context.defineType(def);
								
							}
						}
					case _:
				}
			case _:
		}
	}
	
	static function createBindingFunctionField(init:Array<Expr>, target:Expr, name:String, args:Array<{t:Type, name:String}>, ret:Type, pos:Position):Field {
		return {
			pos: pos,
			name: name,
			access: [APublic, AStatic],
			kind: FFun({
				args: [{name: '__vm', type: macro:wren.WrenVM}],
				ret: macro:Void,
				expr: {
					final exprs = init;
					for(i => arg in args) {
						exprs.push(createReadArgExpr(macro __vm, i, arg.name, arg.t, pos));
					}
					
					switch ret.getID() {
						case 'Void':
							exprs.push(macro $target.$name($a{args.map(a -> macro $i{a.name})}));
							exprs.push(macro __vm.setSlotNull(0));
						case _:
							exprs.push(macro final __ret = $target.$name($a{args.map(a -> macro $i{a.name})}));
							exprs.push(createReturnExpr(macro __vm, macro __ret, ret, pos));
					}
					
					macro $b{exprs}
				}
			}),
		}
	}
	
	static function createReadArgExpr(vm:Expr, index:Int, name:String, type:Type, pos:Position):Expr {
		final e = switch type.toComplex() {
			case macro:StdTypes.Int:
				macro Std.int($vm.getSlotDouble($v{index + 1}));
			case macro:StdTypes.Float:
				macro $vm.getSlotDouble($v{index + 1});
			case macro:StdTypes.Bool:
				macro $vm.getSlotBool($v{index + 1});
			case macro:String:
				macro $vm.getSlotString($v{index + 1});
			case v:
				trace(v);
				macro null; // TODO
		}
		
		return macro @:pos(pos) final $name = $e;
	}
	
	static function createReturnExpr(vm:Expr, expr:Expr, type:Type, pos:Position):Expr {
		
		return switch type.toComplex() {
			case (macro:StdTypes.Int) | (macro:StdTypes.Float):
				macro $vm.setSlotDouble(0, $expr);
			case macro:StdTypes.Bool:
				macro $vm.setSlotBool(0, $expr);
			case macro:String:
				macro $vm.setSlotString(0, $expr);
			case v:
				macro $vm.setSlotNull(0);
		}
	}
}