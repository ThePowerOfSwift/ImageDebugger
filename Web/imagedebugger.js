var db = firebase.firestore();

var sessionsRef = db.collection('sessions');

// Get latest session info
sessionsRef.orderBy('sessionStartTime', 'desc').limit(1)
.onSnapshot(function(sessionSnapshot) {
	sessionSnapshot.forEach(function(sessionDoc) {
		// NEW SESSION
		clearOldData();
		getDataFromSession(sessionDoc);
	});
});

// Remove all images on the page
function clearOldData() {
	$('#images').empty();
}

// Get and insert all images from session doc
function getDataFromSession(sessionDoc) {
	// Update the session info header
	var sessionData = sessionDoc.data();
	updateUIWithSessionStartTime(sessionData.sessionStartTime.toDate());

	// Listen for new images from the images subcollection
	// (inital query contains all existing images as well)
	var imagesRef = sessionsRef.doc(sessionDoc.id).collection('images');
	imagesRef.orderBy('captureTime', 'asc').onSnapshot(function(imageSnapshot) {
		imageSnapshot.docChanges().forEach(function(change) {
			if (change.type === "added") {
				// NEW IMAGE
				var data = change.doc.data();
				updateUIWithImage(data.captureTime.toDate(),
							  	  data.link,
							  	  data.message);
			}
		});
	});
}

function updateUIWithSessionStartTime(date) {
	$('#session-info').text('Session started at ' + date.toLocaleString());
}

function updateUIWithImage(date, link, message) {
	$('#images').prepend('<div class="row"><div class="col-xs-9 center-xs"><img src="' + link + '" alt="' + message + '"></div><div class="col-xs"><p>' + message + '</p><p>Logged at ' + date.toLocaleString() + '</p><p><a href="' + link + '">Download</a></p></div></div>');
}