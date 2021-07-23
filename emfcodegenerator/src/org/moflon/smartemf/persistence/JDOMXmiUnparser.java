package org.moflon.smartemf.persistence;

import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.stream.Collectors;

import org.eclipse.emf.ecore.EAttribute;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EFactory;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.emf.ecore.EcorePackage;
import org.eclipse.emf.ecore.resource.Resource;
import org.jdom2.Attribute;
import org.jdom2.Document;
import org.jdom2.Element;
import org.jdom2.Namespace;
import org.moflon.smartemf.runtime.SmartPackage;

public class JDOMXmiUnparser {

		final public static String XMI_ROOT_NODE = "XMI";
		final public static String XMI_NS = "xmi";
		final public static String XMI_URI = "http://www.omg.org/XMI";
		final public static String XMI_VERSION_ATR = "version";
		final public static String XMI_VERSION = "2.0";
		
		final public static String XSI_NS = "xsi";
		final public static String XSI_URI = "http://www.w3.org/2001/XMLSchema-instance";
		final public static String XSI_TYPE_ATR = "type";
		
		Map<EPackage, Namespace> metamodel2NS = new HashMap<> ();
		Map<EObject, String> object2ID = new HashMap<>();
		Map<EObject, List<Consumer<String>>> waitingCrossRefs = new HashMap<>();
	
		public void modelToJDOMTree(final Resource resource, final Document domTree) throws IOException {
			// Create tree by traversing model
			if(resource.getContents().size()> 1 || resource.getContents().size()< 1) {
				Element root = new Element(XMI_ROOT_NODE, XMI_NS, XMI_URI);
				domTree.setRootElement(root);
				
				int idx = 0;
				for(EObject container : resource.getContents()) {
					root.getChildren().add(createDOMTree(container, container, null, "/"+idx, 0, false));
					idx++;
				}
			} else {
				EObject container = resource.getContents().get(0);
				domTree.setRootElement(createDOMTree(container, container, null, "/", 0, false));
			} 
			
			// Add default xmi namespaces and version attribute
			if(resource.getContents().size() <= 1) {
				Namespace xmiNS = Namespace.getNamespace(XMI_NS, XMI_URI);
				domTree.getRootElement().addNamespaceDeclaration(xmiNS);
			}
			
			Namespace xsiNS = Namespace.getNamespace(XSI_NS, XSI_URI);
			domTree.getRootElement().addNamespaceDeclaration(xsiNS);
			
			for(EPackage pkg : metamodel2NS.keySet()) {
				domTree.getRootElement().addNamespaceDeclaration(metamodel2NS.get(pkg));
			}
			
			domTree.getRootElement().getAttributes().add(new Attribute(XMI_VERSION_ATR, XMI_VERSION, Namespace.getNamespace(XMI_NS, XMI_URI)));
		}
		
		@SuppressWarnings("unchecked")
		protected Element createDOMTree(EObject root, EObject currentEObject, EReference containment, String id, int idx, boolean useSimple) throws IOException {
			EClass currentClass = currentEObject.eClass();
			EPackage metamodel = currentClass.getEPackage();
			
			Namespace ns = null;
			if(!metamodel2NS.containsKey(metamodel)) {
				ns = Namespace.getNamespace(metamodel.getName(), metamodel.getNsURI());
				metamodel2NS.put(metamodel, ns);
			} else {
				ns = metamodel2NS.get(metamodel);
			}
			
			String currentId = id;
			Element current = null;
			if(containment != null) {
				current = new Element(containment.getName());
				EPackage rootMetamodel = root.eClass().getEPackage();
				if(metamodel != rootMetamodel) {
					current.getAttributes().add(new Attribute(XSI_TYPE_ATR, metamodel2NS.get(metamodel).getPrefix()+":"+currentClass.getName(), 
							Namespace.getNamespace(XSI_NS, XSI_URI)));
				}
				
				// This a workaround for a useless/annoying xml simplification that occurs when a child list is exactly of size 1, then the index is omitted.
				if(useSimple) {
					currentId = id + "/@" + containment.getName();
				} else {
					currentId = id + "/@" + containment.getName() + "." + idx;
				}
				
			} else {
				current = new Element(currentClass.getName(), ns);
			}
			
			object2ID.put(currentEObject, currentId);
			if(waitingCrossRefs.containsKey(currentEObject)) {
				for(Consumer<String> consumer : waitingCrossRefs.get(currentEObject)) {
					consumer.accept(currentId);
				}
			}
			
			// Containments
			for(EReference containmentRef : currentClass.getEAllContainments()) {
				List<EObject> containees = new LinkedList<>();
				if(containmentRef.isMany()) {
					containees.addAll((Collection<? extends EObject>) currentEObject.eGet(containmentRef));
				} else {
					EObject containee = (EObject) currentEObject.eGet(containmentRef);
					if(containee != null)
						containees.add(containee);
				}
				int idIDX = 0;
				for(EObject containee : containees) {
					current.getChildren().add(createDOMTree(root, containee, containmentRef, id, idIDX, containees.size()==1));
					idIDX++;
				}
			}
			
			// Crossrefs
			for(EReference crossRef : currentClass.getEAllReferences().stream()
					.filter(ref -> !ref.isContainment())
					.filter(ref -> {
						if(!(metamodel instanceof SmartPackage)) {
							return true;
						} else {
							SmartPackage smartMetamodel = (SmartPackage) metamodel;
							return !smartMetamodel.isDynamicEStructuralFeature(currentClass, ref);
						}
					}).collect(Collectors.toList())) {
				
				LinkedList<EObject> refs = new LinkedList<>();
				if(crossRef.isMany()) {
					refs.addAll((Collection<? extends EObject>) currentEObject.eGet(crossRef));
				} else {
					EObject currentRef = (EObject) currentEObject.eGet(crossRef);
					if(currentRef != null)
						refs.add(currentRef);
				}
				if(refs.isEmpty())
					continue;
				
				
				Attribute refAtr = new Attribute(crossRef.getName(), "");
				PendingXMLCrossReference pendingCrossRefs = new PendingXMLCrossReference(current, refAtr, refs.size());
				if(refs.size()<2) {
					if(object2ID.containsKey(refs.get(0))) {
						pendingCrossRefs.insertID(object2ID.get(refs.get(0)), 0);
					} else {
						// Remember this crossRef and wait for traversal
						List<Consumer<String>> otherPendingRefs = waitingCrossRefs.get(refs.get(0));
						if(otherPendingRefs == null) {
							otherPendingRefs = new LinkedList<>();
							waitingCrossRefs.put(refs.get(0), otherPendingRefs);
						}
						otherPendingRefs.add((crossRefID) -> {
							pendingCrossRefs.insertID(crossRefID, 0);
							if(pendingCrossRefs.isCompleted()) {
								pendingCrossRefs.writeBack();
							}
						});
					}
					
				} else if(refs.size()>1) {
					int crossRefIdx = 0;
					for(EObject ref : refs) {
						if(object2ID.containsKey(ref)) {
							pendingCrossRefs.insertID(object2ID.get(ref), crossRefIdx);
						} else {
							// Remember this crossRef and wait for traversal
							List<Consumer<String>> otherPendingRefs = waitingCrossRefs.get(ref);
							if(otherPendingRefs == null) {
								otherPendingRefs = new LinkedList<>();
								waitingCrossRefs.put(ref, otherPendingRefs);
							}
							final int currentIdx = crossRefIdx;
							otherPendingRefs.add((crossRefID) -> {
								pendingCrossRefs.insertID(crossRefID,  currentIdx);
								if(pendingCrossRefs.isCompleted()) {
									pendingCrossRefs.writeBack();
								}
							});
						}
						crossRefIdx++;
					}
					
				}
				
				if(pendingCrossRefs.isCompleted())
					pendingCrossRefs.writeBack();
				
			}
			
			// Attributes
			EFactory factory = metamodel.getEFactoryInstance();
			for(EAttribute attribute : currentClass.getEAllAttributes()) {
				String value = valueToString(factory, attribute, currentEObject.eGet(attribute));
				if(value == null)
					continue;
				
				Attribute refAtr = new Attribute(attribute.getName(), value);
				current.getAttributes().add(refAtr);
			}
			return current;
		}
		
		public static String valueToString(final EFactory factory, final EAttribute atr, final Object value) throws IOException {
			EcorePackage epack = EcorePackage.eINSTANCE;
			if(atr.getEAttributeType() == epack.getEString()) {
				return (String) value;
			} else if(atr.getEAttributeType() == epack.getEBoolean()) {
				return String.valueOf(value);
			} else if(atr.getEAttributeType() == epack.getEByte()) {
				return String.valueOf(value);
			} else if(atr.getEAttributeType() == epack.getEChar()) {
				return String.valueOf(value);
			} else if(atr.getEAttributeType() == epack.getEDate()) {
				return ((SimpleDateFormat)value).toLocalizedPattern();
			} else if(atr.getEAttributeType() == epack.getEDouble()) {
				return String.valueOf(value);
			}  else if(atr.getEAttributeType() == epack.getEFloat()) {
				return String.valueOf(value);
			} else if(atr.getEAttributeType() == epack.getEInt()) {
				return String.valueOf(value);
			} else if(atr.getEAttributeType() == epack.getELong()) {
				return String.valueOf(value);
			} else if(atr.getEAttributeType() == epack.getEShort()) {
				return String.valueOf(value);
			} else if(atr.getEAttributeType() == epack.getEFeatureMapEntry()) {
				return null;
			}else {
				return factory.convertToString(atr.getEAttributeType(), value);
			}
		}
}

class PendingXMLCrossReference {
	final private Element element;
	final private Attribute attribute;
	final private String[] ids;
	private int insertedIds = 0;
	
	public PendingXMLCrossReference(final Element element, final Attribute attribute, int numOfIds) {
		this.element = element;
		this.attribute = attribute;
		ids = new String[numOfIds];
	}
	
	public void insertID(final String id, int idx) {
		ids[idx] = id;
		insertedIds++;
	}
	
	public boolean isCompleted() {
		return insertedIds == ids.length;
	}
	
	public void writeBack() {
		StringBuilder sb = new StringBuilder();
		for(int i = 0; i<ids.length; i++) {
			sb.append(ids[i]);
			if(i < ids.length-1) {
				sb.append(" ");
			}
		}
		if(sb.toString().isBlank())
			return;
		
		attribute.setValue(sb.toString());
		element.getAttributes().add(attribute);
	}
}