importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBnzd38x3CF2f2ccntI6iHLjSGoq4IyqRE',
  appId: '1:128720778231:web:59c324092177f445ebf4f2',
  messagingSenderId: '128720778231',
  projectId: 'attendence-a56dd',
  authDomain: 'attendence-a56dd.firebaseapp.com',
  storageBucket: 'attendence-a56dd.firebasestorage.app',
});

const messaging = firebase.messaging();

// Background message handler
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
