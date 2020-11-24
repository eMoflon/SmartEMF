package emfcodegenerator

import org.eclipse.emf.ecore.impl.EStructuralFeatureImpl
import java.util.HashSet
import java.util.HashMap
import org.eclipse.emf.ecore.EReference

import org.eclipse.emf.ecore.impl.EAttributeImpl
import org.eclipse.emf.ecore.impl.EReferenceImpl

class Methodgenerator {
	/**EList are used for attributes which are of type list*/
	val static String ELIST_FQ_NAME = "org.eclipse.emf.common.util.EList"
	
	/**EList are used for attributes which are of type list*/
	val static String ELIST_NAME = "EList"
	
	/**the EAttribute EReference*/
	var EStructuralFeatureImpl ref_or_attr
	
	/**how many of these references can be contained:
	 * -1: unbounded ; -2: unspecified; positive -> bounded */
	var int upper_bound
	
	/**true-> contains multiple; false->not*/
	var boolean contains_multiple_elements
	
	/**true -> needs setter; false -> not*/
	var boolean needs_setter_method
	
	/**if true attributes need isSet and unset methods*/
	var boolean needs_set_status_checking
	
	/**true-> attr can only contain unique elements*/
	var boolean is_unique
	
	/**true-> order needs to be kept*/
	var boolean is_ordered
	
	/**needed for implementation. containment ?*/
	var boolean is_contained
	
	/**contains method declarations for the interface*/
	var HashSet<String> method_declarations_for_interface
	
	/**contains declaration (key) and implementation (value) for source*/
	var HashMap<String,String> method_implementation
	
	/**stores the EAttribute's class name example: HashSet*/
	var String einstance_class_name = null
	
	/**stores the EReference's instance type*/
	var String einstance_type_name = null
	
	/**stores the name of the field used for method naming. example: myattribute -> Myattribute*/
	var String capitalized_field_name
	

	new(EStructuralFeatureImpl object_field){
		method_declarations_for_interface = new HashSet<String>()
	    method_implementation = new HashMap<String,String>()
		ref_or_attr = object_field
		upper_bound = object_field.upperBound

		switch(object_field.upperBound){
			case MultiplicityEnum.SINGLE_ELEMENT: {
				contains_multiple_elements = false
				needs_setter_method = object_field.isChangeable
			}
			case MultiplicityEnum.UNBOUNDED: {
				//unbounded fields do not get setters
				contains_multiple_elements = true
				needs_setter_method = false
			}
			case MultiplicityEnum.UNSPECIFIED: {
				contains_multiple_elements = true
				needs_setter_method = object_field.isChangeable
			}
			default: {
				println("unspecified boundaries for object field " + object_field.name)
				contains_multiple_elements = true
				needs_setter_method = object_field.isChangeable
			}
		}

		needs_set_status_checking = object_field.unsettable
		is_unique = object_field.unique
		is_ordered = object_field.ordered
		is_contained = object_field.isContainment

		//EReference's and EAttribute's store their type name differently
		if(ref_or_attr instanceof EAttributeImpl){
			//EAttributes store their attribute type in the instanceClassName field as
			//fq-class name. example: java.util.HashMap
			var instance_class_as_array = ref_or_attr.EAttributeType.instanceClassName
													 .toString().split("\\.")
			//split at every "." and get last element which is the classes name
			einstance_class_name = instance_class_as_array.get(instance_class_as_array.length -1)
		}
		else if(ref_or_attr instanceof EReferenceImpl){
			//EReference's store their type in the name attribute
			einstance_type_name = ref_or_attr.getEType.name
		}
		else throw new IllegalArgumentException("Unsupported Input")
		
		capitalized_field_name = ref_or_attr.name.substring(0, 1).toUpperCase() +
							     ref_or_attr.name.substring(1);
	}
	
	def String make_setter_stump(){
		var datatype = (ref_or_attr instanceof EReference) ?
					   einstance_type_name : einstance_class_name
		return '''    void set«capitalized_field_name»(«datatype» value)'''.toString()
	}
	
	def String make_getter_stump(){
		var datatype = (ref_or_attr instanceof EReference) ?
					   einstance_type_name : einstance_class_name
	    datatype = (contains_multiple_elements) ? '''«ELIST_NAME»<«datatype»>''' : datatype
		return '''    «datatype» get«capitalized_field_name»()'''.toString()
	}
	
	def HashSet<String> get_interface_declarations(){
		method_declarations_for_interface.add(make_getter_stump())
		if(needs_setter_method) method_declarations_for_interface.add(make_setter_stump())
		
		return method_declarations_for_interface
	}
}