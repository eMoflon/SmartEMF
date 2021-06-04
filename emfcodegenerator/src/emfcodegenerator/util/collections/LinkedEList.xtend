package emfcodegenerator.util.collections

import emfcodegenerator.notification.SmartEMFNotification
import emfcodegenerator.util.MinimalSObjectContainer
import java.util.Collection
import java.util.Collections
import java.util.HashSet
import java.util.LinkedList
import java.util.Set
import java.util.function.Predicate
import java.util.function.UnaryOperator
import java.util.stream.Collectors
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.resource.Resource
import emfcodegenerator.util.collections.SmartEMFListIterator.PseudoListIterator
import emfcodegenerator.util.SmartObject
import org.eclipse.emf.ecore.InternalEObject
import org.eclipse.emf.ecore.resource.Resource.Internal

class LinkedEList<E> extends LinkedList<E> implements MinimalSObjectContainerCollection<E> {

	/**########################Attributes########################*/

	/**
	 * the container of this class or null. needed when inspecting references which
	 * have the containment flag set to true
	 */
	var EObject the_eContainer = null

	/**
	 * the EStructuralFeature which contains this class as an target or null if Containment is false
	 */
	var EStructuralFeature the_econtaining_feature = null

	/**
	 * stores if this list is used to store a Containment
	 */
	var boolean is_containment_object = false
	
	/**
	 * stores Notifications for merging or sends them immediately 
	 */
	val notifications = new ListNotificationBuilder
	
	/**
	 * stores the resource in which the objects are stored
	 */
	var Resource resource = null
	/**########################Constructors########################*/

	/**
	 * Constructs new LinkedEList and sets the {@link #the_eContainer eContainer} and the
	 * {@link #the_econtaining_feature eContaining-Feature} to the given values.
	 * @param eContainer EObject
	 * @param eContaining_feature EStructuralFeature
	 * @author Adrian Zwenger
	 */
	new(EObject eContainer, EStructuralFeature eContaining_feature){
		super()
		this.the_eContainer = eContainer
		this.is_containment_object = true
		this.the_econtaining_feature = eContaining_feature
	}
	
	/**
	 * Constructs new LinkedEList from a given Collection and sets the
	 * {@link #the_eContainer eContainer} and the
	 * {@link #the_econtaining_feature eContaining-Feature} to the given values.
	 * @param c Collection<? extends E>
	 * @param eContainer EObject
	 * @param eContaining_feature EStructuralFeature
	 * @author Adrian Zwenger
	 */
	new(Collection<? extends E> c, EObject eContainer, EStructuralFeature eContaining_feature){
		super(c)
		this.the_eContainer = eContainer
		this.the_econtaining_feature = eContaining_feature
		this.is_containment_object = true
	}
	
	/**
	 * Constructs new LinkedEList from a given Collection. The
	 * {@link #the_eContainer eContainer} and the
	 * {@link #the_econtaining_feature eContaining-Feature} are set as null.
	 * @param c Collection<? extends E>
	 * @author Adrian Zwenger
	 */
	new(Collection<? extends E> c){
		super(c)
	}
	
	new(Resource rs){
		this.resource = rs
	}
	/**
	 * Constructs new LinkedEList. The
	 * {@link #the_eContainer eContainer} and the
	 * {@link #the_econtaining_feature eContaining-Feature} are set as null.
	 * @author Adrian Zwenger
	 */
	new(){
		super()
	}

	/**########################MinimalSObjectContainer methods########################*/
	
	override eContainer() {
		return this.the_eContainer
	}
	
	override eContainingFeature() {
		return this.the_econtaining_feature
	}
	
	override reset_containment() {
		this.is_containment_object = false
		this.the_eContainer = null
		this.the_econtaining_feature = null
		for(E object : this){
			try{
				(object as MinimalSObjectContainer).reset_containment()
			} catch (Exception e){
				throw new IllegalArgumentException(
			"The contents of this list do not implement MinimalSObjectContainer. Containments cannot be handled.", e
				)
			}
		}
	}

	override set_containment(EObject container, EStructuralFeature feature) {
		this.is_containment_object = true
		this.the_eContainer = container
		this.the_econtaining_feature = feature
		for(E object : this){
			try{
				(object as MinimalSObjectContainer).set_containment(container, feature)
			} catch (Exception e){
				throw new IllegalArgumentException(
			"The contents of this list do not implement MinimalSObjectContainer. Containments cannot be handled.", e
				)
			}
		}
	}

	override is_containment_object(){
		return is_containment_object
	}

	/**
	 * if this list is a containment list, passed objects will have their containment set and returned.
	 * if it is not, the object will be returned unchanged
	 */
	override E set_containment_to_passed_object(E obj){
		if(is_containment_object){
			try{
				(obj as MinimalSObjectContainer).set_containment(this.the_eContainer, this.the_econtaining_feature)
			} catch (Exception e){
				throw new IllegalArgumentException(
			"The contents of this list do not implement MinimalSObjectContainer. Containments cannot be handled.", e
				)
			}
		}
		return obj
	}
	
	/**
	 * if this list is a containment list, the containment will be removed from the passed object and it will be returned
	 * if it is not, the object will be returned unchanged
	 */
	override E remove_containment_to_passed_object(E obj){
		if(is_containment_object){
			try{
				(obj as MinimalSObjectContainer).reset_containment()
			} catch (Exception e){
				throw new IllegalArgumentException(
			"The contents of this list do not implement MinimalSObjectContainer. Containments cannot be handled.", e
				)
			}
		}
		return obj
	}

	/**########################EList methods which need to be implemented########################*/

	override move(int newPosition, Object object) {
		if(this.contains(object) && (newPosition<super.size) && (newPosition>=0)){
			this.move(newPosition, this.indexOf(object))
		}
	}
	
	override move(int newPosition, int oldPosition) {
		//https://docs.oracle.com/javase/6/docs/api/java/util/Collections.html#rotate%28java.util.List,%20int%29
		if(newPosition<0 || oldPosition<0 || newPosition>=this.size || oldPosition>=this.size)
			throw new IndexOutOfBoundsException()
		val E obj = this.get(oldPosition)
		var int j = oldPosition
		var int k = newPosition
		Collections.rotate(this.subList(j < k ? j : k, (j < k ? k : j) + 1), j < k ? -1 : 1);
		addNotification[SmartEMFNotification.moveInList(eContainer, eContainingFeature, obj, oldPosition, newPosition)]
		return obj;
	}

	/**########################methods which need to be re-implemented########################*/
	
	override add(int index, E obj){
		//this.set_containment_to_passed_object(obj)
		addNotification[SmartEMFNotification.addToFeature(eContainer, eContainingFeature, obj, index)]
		super.add(index, this.set_containment_to_passed_object(obj))
	}
	
	override add(E obj){
		val added = addNotification[SmartEMFNotification.addToFeature(eContainer, eContainingFeature, obj, size)]
		super.add(this.set_containment_to_passed_object(obj))
//		if(resource !== null){
// 		if(obj instanceof SmartObject)(obj as SmartObject).resource = resource
// 		else (obj as InternalEObject).eSetResource(resource as Internal, SmartEMFNotification.addToFeature(eContainer, eContainingFeature, obj, size))
// 		}
		added
	}
	
	override addFirst(E obj){
		addNotification[SmartEMFNotification.addToFeature(eContainer, eContainingFeature, obj, 0)]
		super.addFirst(this.set_containment_to_passed_object(obj))
	}

	override addLast(E obj){
		add(obj)
	}

	override addAll(Collection<? extends E> c) {
		var int old = this.size()
		notifications.enableAccumulation
		for(E e: c) this.add(this.set_containment_to_passed_object(e))
		notifications.flush
		return old !== this.size()
	}

	override clear(){
		this.removeAll(new HashSet(this))
	}

	override offer(E obj){
		add(obj)
	}

	override offerFirst(E obj){
		addFirst(obj)
		true
	}

	override offerLast(E obj){
		add(obj)
	}
	
	override pollFirst(){
		poll
	}
	
	override pollLast(){
		if (!isEmpty) removeLast else null
	}

	override poll(){
		if (!isEmpty) removeFirst else null
	}
	
	override pop(){
		removeFirst
	}
	
	override push(E obj){
		addFirst(obj)
	}
	
	override remove(){
		removeFirst
	}
	
	override remove(Object obj){
		val removed = super.remove(obj)
		if (removed) {
			addNotification[SmartEMFNotification.removeFromFeature(eContainer, eContainingFeature, obj, -1)] //finding the index would take too long
			this.remove_containment_to_passed_object(obj as E)
		}
		return removed
	}
	
	override remove(int index){
		addNotification[SmartEMFNotification.removeFromFeature(eContainer, eContainingFeature, get(index), index)]
		return this.remove_containment_to_passed_object(super.remove(index))
	}
	
	override removeFirst(){
		remove(0)
	}
	
	override removeFirstOccurrence(Object o){
		return this.remove(o)
	}
	
	override removeLast(){
		remove(size - 1)
	}
	
	override removeLastOccurrence(Object o){
		var int index = super.lastIndexOf(o)
		if(index > -1){
			this.remove(index)
			return true
		}
		return false
	}
	
	override removeAll(Collection<?> c){
		val old = size
		if (old == 0) return false
		val toBeRemoved = if (c instanceof Set) c else new HashSet(c)
		notifications.enableAccumulation
		while (toBeRemoved.contains(first)) {
			removeFirst
		}
		subList(1, size).removeAll(toBeRemoved)
		notifications.flush
		return old !== size
	}
	
	override removeRange(int a, int b){
		subList(a, b).clear
	}
	
	override set(int index, E obj){
		val oldValue = this.get(index)
		this.remove_containment_to_passed_object(oldValue)
		addNotification[SmartEMFNotification.set(eContainer, eContainingFeature, oldValue, obj, index)]
		super.set(index, this.set_containment_to_passed_object(obj))
	}
	
	override retainAll(Collection<?> c){
		var int old = this.size()
		notifications.enableAccumulation
		for(E obj : this){
			if(!(c.contains(obj))){
				this.remove(obj)
			}
		}
		notifications.flush
		return old !== this.size()
	}
	
	override removeIf(Predicate<? super E> filter){
		val toBeRemoved = this.stream().filter(filter).collect(Collectors.toSet)
		removeAll(toBeRemoved)
	}
	
	override replaceAll(UnaryOperator<E> operator){
		val LinkedList<Pair<Integer,E>> toBeReplaced = new LinkedList
		var index = 0
		for (E e : this) {
			val newE = operator.apply(e)
			if (e !== newE) {
				toBeReplaced.add(index -> newE)
			}
			index++
		}
		for (x : toBeReplaced) {
			set(x.getKey, x.getValue)
		}
	}

	override iterator(){
		return new SmartEMFCollectionIterator(super.iterator, this)
	}
	
	override listIterator(){
		return new SmartEMFListIterator(super.listIterator, this)
	}
	
	override listIterator(int index){
		return new SmartEMFListIterator(super.listIterator(index), this)
	}
	
	override notificationBuilder() {
		notifications
	}
}