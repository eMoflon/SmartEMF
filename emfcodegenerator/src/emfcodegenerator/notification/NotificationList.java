package emfcodegenerator.notification;

import java.util.LinkedList;

import org.eclipse.emf.common.notify.Notification;
import org.eclipse.emf.common.notify.NotificationChain;
import org.eclipse.emf.common.notify.Notifier;

public class NotificationList extends LinkedList<Notification> implements NotificationChain {

	private static final long serialVersionUID = -8325604720792490293L;

	public NotificationList(Iterable<Notification> notifications) {
		super();
		for (Notification n: notifications) {
			add(n);
		}
	}
	
	public NotificationList(Notification... notifications) {
		super();
		for (Notification n: notifications) {
			add(n);
		}
	}
	
	@Override
	public void dispatch() {
		for (Notification n : this) {
			Notifier notifier = (Notifier)(n.getNotifier());
			notifier.eNotify(n);
		}
	}

}