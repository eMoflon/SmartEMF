package emfcodegenerator
/*
 * @author Adrian Zwenger
 */
import java.io.File;
import java.io.FileWriter
import java.util.Set
import java.util.HashSet
import java.util.Arrays
import org.eclipse.emf.ecore.EAttribute
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.impl.EClassImpl
import java.util.Collections
import org.eclipse.emf.ecore.EPackage
import com.sun.org.apache.xerces.internal.dom.EntityReferenceImpl
import org.eclipse.emf.ecore.impl.EStructuralFeatureImpl

class ModelFileGenerator {
	/**sub-folder where all generated classes are stored*/
	val static String GENERATED_FILE_PATH = "./src-gen/"
	
	/**EList are used for attributes which are of type list*/
	val static String ELIST_FQ_NAME = "org.eclipse.emf.common.util.EList"
	
	/**EList are used for attributes which are of type list*/
	val static String ELIST_NAME = "EList"

	/**Set containing fqdn for classes to be imported */
	Set<String> imports
	
	/**stores generated method stumps as for interfaces*/
	Set<String> interface_method_declarations
	
	/**stores all EAttributes which are not inherited */
	Set<EAttribute> class_attributes
	
	/**stores all inherited EAttributes */
	Set<EAttribute> inherited_class_attributes

	/**stores all EReference which are not inherited */
	Set<EReference> class_references
	
	/**stores all inherited EReference */
	Set<EReference> inherited_class_references
	
	/**stores the super-package for all files specified by genmodel-xmi */
	String genmodel_specified_superpackage

	/**stores the EClass object for which the file shall be generated */
	EClass e_class

	/** String which represents the classes file-path in a package hierarchy*/
	String base_path
	
	/**String representing the package declaration of the e_classes interface */
	String package_declaration_for_interface
	
	/**String representing the package declaration of the e_classes implementation */
	String package_declaration_for_source

	/**
	 * construct a new ModelFileGenerator instance, with which Interfaces for the EMF model can be
	 * generated
	 * One ModelFileGenerator creates exactly one file
	 * TODO add source code generation support
	 * @param path String which represents the file-path in a package hierarchy
	 * 		  example: package_one/package_two/MyClass
	 * @param e_class is the ECLass object to be implemented as interface or as Source
	 * @param genmodel_specified_superpackage String indicating a super package for all files and
	 *		  packages (specified by genmodel-xmi)
	 */
	new(String path, EClass e_class, String genmodel_specified_superpackage){
		this.e_class = e_class
		//using synchronised HashSet in case code is to be expanded for multi-threading
		imports = Collections.synchronizedSet(new HashSet<String>())
		interface_method_declarations = Collections.synchronizedSet(new HashSet<String>())
		base_path = path
		this.genmodel_specified_superpackage = genmodel_specified_superpackage

		//model registration
		register_package_declarations()
		register_imports()
		register_attributes()
		register_references()
	}

	//############# Registration methods #############//
	
	/**registers package declaration and stores them as string
	* the package-path is calculated by helper functions and derived from the base_path
	* passed to this object-instance
	* See:
	*	- convert_regular_file_name_path_to_implementation_type
	*	- get_package_declaration_for_file
	*/
	def void register_package_declarations(){
		var fq_path = convert_regular_file_name_path_to_implementation_type(base_path)
		package_declaration_for_source = convert_fqdn_file_path_to_package_name(fq_path)
		package_declaration_for_interface = convert_fqdn_file_path_to_package_name(base_path)
	}
	
	/**registers all attributes (inherited and own) to their respective HashSet */
	def private void register_attributes(){
		class_attributes = Collections.synchronizedSet(
						   		new HashSet<EAttribute>((e_class as EClassImpl).EAttributes))
		inherited_class_attributes = Collections.synchronizedSet(new HashSet<EAttribute>())
		for(EAttribute e_attr : e_class.EAllAttributes){
			if(e_attr !== null) {
				inherited_class_attributes.add(e_attr)
				//println(new Methodgenerator(e_attr as EStructuralFeatureImpl).make_setter_stump)
				//println(e_attr instanceof EStructuralFeatureImpl)
				//println(e_attr.getEType.instanceClass)
				//println(e_attr.getEType.name)
			}
		}
	}
	
	/**registers all attributes (inherited and own) to their respective HashSet */
	def private void register_references(){
		class_references = Collections.synchronizedSet(
							new HashSet<EReference>((e_class as EClassImpl).EReferences))
		inherited_class_references = Collections.synchronizedSet(new HashSet<EReference>())
		for(EReference e_ref : class_references){
			if(e_ref !== null){
				inherited_class_references.add(e_ref)
				//println(new Methodgenerator(e_ref as EStructuralFeatureImpl).make_setter_stump)
				//println(e_ref instanceof EStructuralFeatureImpl)
				//println(e_ref.getEType.name)
			}
		}
	}
	
	/**
	 * adds all data-types to the import list which the EClass depends on
	 */
	def private void register_imports(){
		for(EAttribute e_attr : e_class.EAllAttributes){
			add_import(e_attr.EAttributeType.instanceTypeName)
			//a fully qualified name is stored in the instanceTypeName
			if (e_attr.upperBound !== MultiplicityEnum.SINGLE_ELEMENT) {
					add_import(ELIST_FQ_NAME)
					println(e_class.name)
				}
		}
		for(EReference e_ref : e_class.EAllReferences){
			add_import(this.create_import_name_for_ereference_or_eclass(e_ref))
			//generate and add import string for EReferences
			println(e_ref.upperBound)
			if (e_ref.upperBound !== MultiplicityEnum.SINGLE_ELEMENT) {
					add_import(ELIST_FQ_NAME)
					println(e_class.name)
				}
		}
	}

	//############# Helper methods #############//
	
	/**
	 * Takes fqdn file-path without file-extension (relative to root folder of project) and returns
	 * the corresponding package where the file is loaded
	 */
	def private String convert_fqdn_file_path_to_package_name(String fq_file_name){
		var package_path = fq_file_name.replace(GENERATED_FILE_PATH, "").split("/")
		//example for a file path: ./src-gen/package/subpackage/myClass.java
		//thus splitting at every "/" and removing the GENERATED_FILE_PATH part
		return String.join(".", Arrays.copyOfRange(package_path, 0, package_path.size - 1)
		)
	}
	
	/**EClasses and EReferences do not store their data-types proper fq-import name.
	 * The full path can be created by accessing the classes package and then continue to get the
	 * super-package until top layer in the hierarchy has been reached.
	 * Returns a the fq-import name
	 * @param EReference which is to be examined
	 * @return String
	 */
	def private <E> create_import_name_for_ereference_or_eclass(E e_obj){
		var String fqdn
		var EPackage super_package
		if(e_obj instanceof EReference) {
			//check if input is an EReference
			fqdn = (e_obj as EReference).EType.EPackage.name + "." +
				   (e_obj as EReference).EType.name
		    //get reference type and its package
			super_package = (e_obj as EReference).EType.EPackage.ESuperPackage
			//initialise the super package
			}
		else if(e_obj instanceof EClass){
			//same for EClasses
			fqdn = (e_obj as EClass).EPackage.name + "." + (e_obj as EClass).name
			super_package = (e_obj as EClass).EPackage.ESuperPackage
		} else {
			throw new IllegalArgumentException("expected EReference or EClass. Got: " + e_obj.class)
		}
		while(super_package !== null){
			//EMF sets the ESuperPackage attribute to null if there is no super-package
			//traverse package hierarchy until top-layer is reached
			fqdn = super_package.name + "." + fqdn
			super_package = super_package.ESuperPackage
		}
		//The super-layer package specified in the genmodel-xmi is not stored in the ECLass structure
		//thus needs to be added manually
		return (genmodel_specified_superpackage === null ||
				genmodel_specified_superpackage.isEmpty) ? 
				fqdn : genmodel_specified_superpackage + "." + fqdn
	}

	/**
	 * Helper Method. converts a normal interface path into an implementation file path
	 * Example: org/my_emf/classes/Myclass.java
	 *			-->
	 * 			org/my_emf/classes/impl/MyclassImpl.java
	 * @param String file path and name
	 * @return converted path
	 */
	def private static String convert_regular_file_name_path_to_implementation_type(String fqdn){
		var buffer = fqdn.split("/")
		return GENERATED_FILE_PATH +
		       String.join("/", Arrays.copyOfRange(buffer, 0, buffer.size - 1)) +
		 	   "/impl/" + buffer.get(buffer.size - 1) + "Impl.java"
	}
	
	/**
	 * registers a single import String. expects it to be properly formed
	 * @param fq-fq_module_name
	 * @return boolean true-->added false-->already contained or null
	 */
	def boolean add_import(String fq_module_name){
		if(!fq_module_name.nullOrEmpty) {
			return imports.add(fq_module_name)
		}
		return false
	}
	
	/**Creates the declaration for the generated EMF source-code. As far as I can see source classes
	 * always extend org.eclipse.emf.ecore.impl.MinimalEObjectImpl und implement their interface
	 * counterpart
	 */
	def private String create_implementation_declaration(){
		add_import("org.eclipse.emf.ecore.impl.MinimalEObjectImpl")
		add_import(package_declaration_for_interface)
		var declaration = ((e_class.abstract) ? "public abstract class " : "public class ") +
		'''«e_class.name + "Impl"» extends MinimalEObjectImpl.Container implements «e_class.name»'''
		.toString()
		return declaration
	}
	
	/**This method creates the declaration for the interface including extension and
	 * implementation flags
	 * Example: public interface MyInterface extends SomeObject implements Stuff, OtherStuff
	 * @returns String
	 */
	def private String create_interface_declaration(){
		var declaration = '''public interface «e_class.name»'''
		var implementing_interfaces = new HashSet<EClass>()
		var extending_classes = new HashSet<EClass>()
		//get interfaces
		for(EClass ecl : e_class.ESuperTypes){
			//discern super types and divide interfaces from classes
			if(ecl.isInterface) implementing_interfaces.add(ecl)
			else extending_classes.add(ecl)
		}
		if(extending_classes.isEmpty() && implementing_interfaces.isEmpty()){
			//EMF interfaces extend the EObject class if it does not extend
			//other classes or implements other interfaces
			declaration = declaration + " extends EObject"
			add_import("org.eclipse.emf.ecore.EObject")
		}
		if (!extending_classes.isEmpty()){
			//if the interface does extend class(es), they need to be declared
			declaration = declaration + " extends "
			var iterator = extending_classes.iterator
			while(iterator.hasNext){
				var super_class = iterator.next
				//import the super package
				add_import(create_import_name_for_ereference_or_eclass(super_class))
				declaration = declaration + super_class.name
				if(iterator.hasNext) declaration = declaration + ", "//only add "," if needed
			}
		}
		if (!implementing_interfaces.isEmpty()){
			//if the interfaces implements interfaces, they need to be declared
			declaration = declaration + " implements "
			var iterator = implementing_interfaces.iterator
			while(iterator.hasNext){
				var super_interface = iterator.next
				//import the super interface
				add_import(create_import_name_for_ereference_or_eclass(super_interface))
				declaration = declaration + super_interface.name
				if(iterator.hasNext) declaration = declaration + ", "//only add "," if needed
			}
		}
		return declaration
	}

	//############# File generators #############//
	
	/**Creates the file and writes all changes to it */
	def void create_interface_file(){
		for(EAttribute e_attr : class_attributes){
			var method_generator = new Methodgenerator(e_attr as EStructuralFeatureImpl)
			interface_method_declarations.addAll(method_generator.get_interface_declarations())
		}
		for(EReference e_attr : class_references){
			var method_generator = new Methodgenerator(e_attr as EStructuralFeatureImpl)
			interface_method_declarations.addAll(method_generator.get_interface_declarations())
		}
		
		//register_method_declarations_for_interface()
		//check which methods need to be generated
		var fq_path = GENERATED_FILE_PATH + base_path + ".java"
		var interface_file = new File(fq_path)
		interface_file.getParentFile().mkdirs()
		//if the path to file does not exist yet, create it
		var interface_fw = new FileWriter(interface_file , false)
		//overwrite file, if existent

		//##generate imports last and then write to file in case any missing dependencies were found
		var package_declaration = "package " + package_declaration_for_interface + ";" +
						   		  System.lineSeparator() + System.lineSeparator()
		//declare the package; the proper package can be derived from the qualified path
		var interface_declaration = create_interface_declaration() + "{" + System.lineSeparator() +
						   			System.lineSeparator()
		//add interface declaration
		var method_declarations = ""
		for(String method : interface_method_declarations) 
			method_declarations += method + ";" + System.lineSeparator()

		//##now write to file
		interface_fw.write(package_declaration)
		for(String import : imports){
			interface_fw.write('''import «import»;'''.toString() + System.lineSeparator())
		}
		interface_fw.write(System.lineSeparator() + interface_declaration)
		interface_fw.write(method_declarations)
		//add methods to interface body
		interface_fw.write(System.lineSeparator() + "}")
		//close interface
		interface_fw.close()
		//close file
	}
	
	/**Creates the file and writes all changes to it 
	 * NOT IMPLEMENTED
	 */
	def void create_source_file(){
		if(e_class.isInterface) return
		var source_file = new File(convert_regular_file_name_path_to_implementation_type(base_path))
		source_file.getParentFile().mkdirs()
		//if the path to file does not exist yet, create it
		var source_fw = new FileWriter(source_file , false)
		
		var package_declaration = "package " + package_declaration_for_source +
							      ";" + System.lineSeparator() + System.lineSeparator()
		var class_declaration = create_implementation_declaration() + " { " + System.lineSeparator()
		var imports_block = ""
		for(import:imports)
			imports_block += '''import «import»;'''.toString() + System.lineSeparator()

		source_fw.write(package_declaration)
		source_fw.write(imports_block)
		source_fw.write(System.lineSeparator() + class_declaration)
		source_fw.write("}")
		source_fw.close()
	}
}