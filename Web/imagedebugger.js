var db = firebase.firestore();

// Get latest session
var sessionsRef = db.collection('sessions');
sessionsRef.orderBy('sessionStartTime', 'desc').limit(1)
.get()
.then(function(sessionSnapshot) {
	sessionSnapshot.forEach(function(sessionDoc) {
		var sessionData = sessionDoc.data();
		updateUIWithSessionStartTime(sessionData.sessionStartTime.toDate());

		// Get every image in the images subcollection
		var imagesRef = sessionsRef.doc(sessionDoc.id).collection('images');
		imagesRef.orderBy('captureTime', 'asc')
		.get()
		.then(function(imagesSnapshot) {
			imagesSnapshot.forEach(function(image) {
				// Add it to the UI
				var imgData = image.data();
				updateUIWithImage(imgData.captureTime.toDate(),
								  imgData.link,
								  imgData.message);
			});
		});

		// Listen for any new images that are added
		imagesRef.onSnapshot(function(imagesSnapshot) {
			imagesSnapshot.docChanges().forEach(function(change) {
				if (change.type == "added") {
					var imgData = change.doc.data();
					updateUIWithImage(imgData.captureTime.toDate(),
									  imgData.link,
									  imgData.message);
				}
			});
		});
	});
});

function updateUIWithSessionStartTime(date) {
	$('#session-info').text('Session started at ' + date.toLocaleString());
}

function updateUIWithImage(date, link, message) {
	$('#images').prepend('<div class="row"><div class="col-xs-9 center-xs"><img src="' + link + '" alt="' + message + '"></div><div class="col-xs"><p>' + message + '</p><p>Logged at ' + date.toLocaleString() + '</p><p><a href="' + link + '">Download</a></p></div></div>');
}