package emfcodegenerator

/*
 * @author Adrian Zwenger
 */

//java.util
import java.util.HashMap;

//org.eclipse.emf.codegen.ecore_2.23.0.v20200701-0840.jar
import org.eclipse.emf.codegen.ecore.genmodel.GenClass;
import org.eclipse.emf.codegen.ecore.genmodel.GenModel;
import org.eclipse.emf.codegen.ecore.genmodel.GenModelPackage;
import org.eclipse.emf.codegen.ecore.genmodel.GenPackage;

//org.eclipse.emf.ecore_2.23.0.v20200630-0516.jar
import org.eclipse.emf.ecore.impl.EPackageImpl
import org.eclipse.emf.ecore.impl.EClassImpl;
import org.eclipse.emf.ecore.impl.EClassifierImpl;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.EObject

//org.eclipse.emf.ecore.xmi_2.16.0.v20190528-0725.jar
import org.eclipse.emf.ecore.xmi.impl.EcoreResourceFactoryImpl;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;



//
import org.eclipse.emf.common.util.URI;
import java.util.Set
import java.util.Arrays

class EcoreGenmodelParser {
	
	//var ArrayList<GenClass> genclasses = new ArrayList<GenClass>()
	/* stores all GenClasses found in the genmodel-xmi */
	var HashMap<String,GenClass> genclass_name_map = new HashMap<String,GenClass>()
	/* maps all GenClasses foun in genmodel-xmi to their URI-name */
	var HashMap<String,EClassImpl> ecoreclass_name_map = new HashMap<String,EClassImpl>()
	/* maps all EClasses found in ecore-xmi to their URI-name */

	var String genmodel_folder
	//the genmodel xmi can specify a toplayer package name
	var String super_package_name = null

	/**return the genmodel-specified superpackage name. Null if non specified */
	def String get_super_package_name() {
		return super_package_name
	}
	
	/** getter for genclass registry */
	def Set<String> get_class_names(){
		return genclass_name_map.keySet()
	}

	/**getter for ecoreclass registry */
	def HashMap<String,EClassImpl> get_class_name_to_object_map(){
		return ecoreclass_name_map
	}

	/**
	 * constructs a new EcoreGenmodelParser
	 * @param String path to the ecore-xmi
	 * @param String path to the genmodel-xmi
	 */
	new(String ecore_path, String genmodel_path){
		var gn_path_array = URI.createFileURI(genmodel_path).toString().split("/")
		genmodel_folder = String.join("/", Arrays.copyOfRange(gn_path_array, 0 , gn_path_array.length -1)) + "/"
		parse_genmodel(genmodel_path)
		parse_ecore(ecore_path)
		//verify that ecore and genmodel contain the same classes
		if(!this.genclass_name_map.keySet().equals(ecoreclass_name_map.keySet())){
			println("1 " + genclass_name_map.keySet())
			println("2 " + ecoreclass_name_map.keySet())
			println(super_package_name)
			throw new UnsupportedOperationException("genmodel and ecore do not specify same classes")
		}
	}

	/**
	 * parses the defined classes from the ecore-xmi and populates object attributes
	 * TODO add support for more than just classes
	 * @param String path to ecore-xmi
	 */
	def private void parse_ecore(String ecore_path){
		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap()
				.put("ecore", new XMIResourceFactoryImpl());
		//register "ecore" as valid file extension
		var epak = (new ResourceSetImpl()).getResource(URI.createFileURI(ecore_path), true)
										  .getContents().get(0) as EPackageImpl
	  	//get super EPackage from ecore-xmi
	  	var proxy_uri_extension = "/" 
	  	// + ".ecore#//")//exchange if the full ProxyUri is used with genmodel
	  	var fq_classname = epak.getName() + proxy_uri_extension
	  	fq_classname = (super_package_name === null || super_package_name.isEmpty) ?
	  					fq_classname : super_package_name + "/" + fq_classname
		this.ecoreclass_name_map = get_ecore_classes(epak, fq_classname)
		//register all classes with fqdn
	}

	/**
	 * recursively registers all classes found in ecore-xmi and creates a HashMap where the key
	 * is a string which represents the classes position in the package hierarchy and the 
	 * EClass as a value itself
	 * @param epak toplevel EPackage
	 * @param package_path String giving the toplevel package path/name
	 */
	def private HashMap<String,EClassImpl> get_ecore_classes(EPackage epak, String package_path){
		var e_classes = new HashMap<String,EClassImpl>()
		//exit recursion as soon as a package has no content at all
		if(epak.eContents().isEmpty()) return e_classes
		//iterate over all objects
		for(EObject e_obj: epak.eContents()){
			if(e_obj instanceof EClassImpl){
				//register all classes in package
				e_classes.put(package_path + (e_obj as EClassImpl).getName(),
							  e_obj as EClassImpl)
			}
		}
		//check if there are subpackages to be scanned as well
		if(epak.getESubpackages().isEmpty()) return e_classes
		//exit recursion if package does not have any sub_packages
		for(EPackage sub_epak : epak.getESubpackages()){
			//repeat process for all subpackages recursively and add all classes to register
			e_classes.putAll(get_ecore_classes(sub_epak, package_path +  sub_epak.getName() + "/"))
		}
		return e_classes
	}

	/**
	 * parses the defined classes from the genmodel-xmi and populates object attributes
	 * TODO add support for more than just classes
	 * @param String path to genmodel-xmi
	 */
	def void parse_genmodel(String genmodel_path){
		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap()
				.put("genmodel", new XMIResourceFactoryImpl())
		// register *.genmodel xmi
		var res_impl = new ResourceSetImpl()
		res_impl.getResourceFactoryRegistry().getExtensionToFactoryMap()
				.put("genmodel", new EcoreResourceFactoryImpl())
		// teach resource how to read *.genmodel
		res_impl.getPackageRegistry().put(GenModelPackage.eNS_URI, GenModelPackage.eINSTANCE)
		// get the genmodel
		var gen_model = res_impl.getResource(URI.createFileURI(genmodel_path), true)
								.getContents().get(0) as GenModel
		//gen_model.
		this.super_package_name = gen_model.getGenPackages().get(0).basePackage
		this.genclass_name_map = get_genmodel_classes(gen_model.getGenPackages().get(0))
		//register all classes found in the genmodel-xmi
	}

	/**
	 * recursively registers all classes found in genmodel-xmi and creates a HashMap where the key
	 * is a string which represents the classes position in the package hierarchy and the 
	 * GenClass as a value itself
	 * @param gp toplevel GenPackage
	 */
	def private HashMap<String,GenClass> get_genmodel_classes(GenPackage gp){
		var gen_classes = new HashMap<String,GenClass>()
		if(gp.eContents().isEmpty()) return gen_classes
		//exit if package is empty
		for(GenClass gc : gp.getGenClasses()){
			var eproxy_uri = (gc.getEcoreClassifier() as EClassifierImpl).eProxyURI()
			var String fq_classname
			if(!eproxy_uri.isFile()){
				 fq_classname = eproxy_uri.toString().replaceAll(".ecore#//", "/")
			} else {
				//if the genmodel file is not in working directory, the whole path is added in front
				//of package hierarchy. needs to be stripped away
				fq_classname = eproxy_uri.toString().replace(genmodel_folder, "")
				 									.replaceAll(".ecore#//", "/")
			}
			
			fq_classname = (super_package_name === null || super_package_name.isEmpty) ?
						   fq_classname : super_package_name + "/" + fq_classname
			gen_classes.put(fq_classname, gc)
			//register all genclasses with their full path
		}
		if(gp.getSubGenPackages().isEmpty()) return gen_classes
		//exit if there are no subpackages
		for(GenPackage gp_sub : gp.getSubGenPackages()){
			gen_classes.putAll(get_genmodel_classes(gp_sub))
			//repeat process for all subpackages
		}
		return gen_classes
	}
}