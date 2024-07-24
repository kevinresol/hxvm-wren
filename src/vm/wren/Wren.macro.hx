package vm.wren;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

using Lambda;
using StringTools;
using tink.MacroApi;

final FOREIGN_CLASS_OPTION = 'foreignClasses';

final ALLOCATE_FIELD = '__wren_allocate';
final FINALIZE_FIELD = '__wren_finalize';

class Wren {
	public static macro function make(options:Expr):Expr {
		final foreignClasses = extractForeignClasses(options);
		
		defineBindingClasses(foreignClasses);
		
		final e = macro {
			final options:vm.wren.Wren.WrenOptions = ${Anon.extractFields(options, ['writeFn', 'errorFn', 'loadModuleFn'])};
			wren.WrenVM.make({
				writeFn: options.writeFn,
				errorFn: options.errorFn,
				loadModuleFn: options.loadModuleFn,
				bindForeignMethodFn: ${makeBindForeignMethodFn(foreignClasses)},
				bindForeignClassFn: ${makeBindForeignClassFn(foreignClasses)}
			});
		}
		return e.log();
	}
	
	/**
		Extract the list foreign classes from the options
	**/
	static function extractForeignClasses(options:Expr):Array<ForeignClassDef> {
		final ret:Array<ForeignClassDef> = [];
		switch options {
			case {expr: EObjectDecl(fields)}:
				
				switch fields.find(f -> f.field == FOREIGN_CLASS_OPTION)?.expr {
					case null:
						options.pos.error('$FOREIGN_CLASS_OPTION option is required');
					case macro $a{foreignClassesExprs}:
						for(e in foreignClassesExprs) {
							final type = Context.getType(e.toString());
							final meta = type.getMeta()[0];
							
							switch meta.extract(':wren.foreign') {
								case [{params: [macro $v{(module:String)}, macro $v{(className:String)}]}]:
									ret.push({module: module, className: className, type: type});
								case v:
									// trace(v);
							}
						}
					case {pos: pos}:
						pos.error('$FOREIGN_CLASS_OPTION option should be an array of classes');
				}
			case _:
		}
		return ret;
	}
	
	/**
		Define the binding classes for the foreign classes
		each of them will contain the static methods that will be called from Wren
	**/
	static function defineBindingClasses(foreignClasses:Array<ForeignClassDef>):Void {
		for(foreignClass in foreignClasses) {
			final type = foreignClass.type;
			final ct = type.toComplex();
			final tp = switch ct {
				case TPath(v): v;
				case _: throw 'Expected TypePath';
			}
			final pos = type.getPosition().sure();
			final meta = type.getMeta()[0];
			final id = type.getID();
			
			if(meta.has(':wren.foreign')) {
				// TODO: only add these if class has constructor
				final fields:Array<Field> = [
					{
						pos: pos,
						name: ALLOCATE_FIELD,
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
						name: FINALIZE_FIELD,
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
							fields.push(makeBindingFunctionField(
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
							fields.push(makeBindingFunctionField(
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
					meta: [{pos: pos, name: ':unreflective'}],
					kind: TDClass(null, [], false, true),
					fields: fields,
				}
				
				// trace(new haxe.macro.Printer().printTypeDefinition(def));
				
				Context.defineType(def);
				
			}
		}
	}
	
	/**
		Make the static function field that will be called from Wren
	**/
	static function makeBindingFunctionField(init:Array<Expr>, target:Expr, name:String, args:Array<{t:Type, name:String}>, ret:Type, pos:Position):Field {
		return {
			pos: pos,
			name: name,
			access: [APublic, AStatic],
			kind: FFun({
				args: [{name: '__vm', type: macro:cpp.Star<wren.native.WrenVM>}],
				ret: macro:Void,
				expr: {
					final exprs = [macro final __vm:wren.WrenVM = __vm].concat(init);
					for(i => arg in args) {
						exprs.push(makeReadArgExpr(macro __vm, i, arg.name, arg.t, pos));
					}
					
					switch ret.getID() {
						case 'Void':
							exprs.push(macro $target.$name($a{args.map(a -> macro $i{a.name})}));
							exprs.push(macro __vm.setSlotNull(0));
						case _:
							exprs.push(macro final __ret = $target.$name($a{args.map(a -> macro $i{a.name})}));
							exprs.push(makeReturnExpr(macro __vm, macro __ret, ret, pos));
					}
					
					macro $b{exprs}
				}
			}),
		}
	}
	
	/**
		Make the expression to read the argument from the Wren VM
	**/
	static function makeReadArgExpr(vm:Expr, index:Int, name:String, type:Type, pos:Position):Expr {
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
	
	/**
		Make the expression to return the result to the Wren VM
	**/
	static function makeReturnExpr(vm:Expr, expr:Expr, type:Type, pos:Position):Expr {
		
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
	
	/**
		Make the expression of the bindForeignClassFn option
	**/
	static function makeBindForeignClassFn(foreignClasses:Array<ForeignClassDef>):Expr {
		final cases:Array<Case> = [];
		
		for(foreignClass in foreignClasses) {
			final type = foreignClass.type;
			final module = foreignClass.module;
			final className = foreignClass.className;
			final target = macro $p{['vm', 'wren', 'WrenForeignBinding_${type.getID().replace('.', '_')}']};
			
			cases.push({
				values: [macro [$v{module}, $v{className}]],
				expr: {
					macro {
						wren.WrenForeignClassMethods.make({
							allocate: cpp.Callable.fromStaticFunction($target.$ALLOCATE_FIELD),
							finalize: cpp.Callable.fromStaticFunction($target.$FINALIZE_FIELD),
						});
					}
				}
			});
		}
		
		return macro (__vm:wren.WrenVM, module:String, className:String) -> 
			${ESwitch(macro [module, className], cases, macro wren.WrenForeignClassMethods.init()).at()}
		}
		
	/**
		Make the expression of the bindForeignMethodFn option
	**/
	static function makeBindForeignMethodFn(foreignClasses:Array<ForeignClassDef>):Expr {
		final cases:Array<Case> = [];
		
		for(foreignClass in foreignClasses) {
			final type = foreignClass.type;
			final module = foreignClass.module;
			final className = foreignClass.className;
			final target = macro $p{['vm', 'wren', 'WrenForeignBinding_${type.getID().replace('.', '_')}']};
			
			for(field in type.getFields().sure()) {
				final fname = field.name;
				switch field.type.reduce() {
					case TFun(args, _):
						final signature = '${field.name}(${args.map(a -> '_').join(',')})';
						cases.push({
							values: [macro [$v{module}, $v{className}, false, $v{signature}]],
							expr: macro cpp.Callable.fromStaticFunction($target.$fname),
						});
					case _:
				}
			}
			
			for(field in type.getStatics().sure()) {
				final fname = field.name;
				switch field.type.reduce() {
					case TFun(args, _):
						final signature = '${field.name}(${args.map(a -> '_').join(',')})';
						cases.push({
							values: [macro [$v{module}, $v{className}, true, $v{signature}]],
							expr: macro cpp.Callable.fromStaticFunction($target.$fname),
						});
					case _:
				}
			}
		}
		
		return macro (__vm:wren.WrenVM, module:String, className:String, isStatic:Bool, signature:String) -> 
			${ESwitch(macro [module, className, isStatic, signature], cases, macro null).at()}
	}
}

class Anon {
	public static function extractFields(obj:Expr, fields:Array<String>): Expr {
		return switch obj {
			case {expr: EObjectDecl(ofields)}:
				EObjectDecl(ofields.filter(f -> fields.indexOf(f.field) != -1)).at(obj.pos);
			case _:
				throw "Expected EObjectDecl";
		}
	}
}

typedef ForeignClassDef = {module:String, className:String, type:Type}