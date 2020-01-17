var db = firebase.firestore();

// Get latest session
db.collection('sessions').orderBy('sessionStartTime', 'desc').limit(1)
.get()
.then(function(querySnapshot) {
	querySnapshot.forEach(function(doc) {
		var data = doc.data();
		updateUIWithSessionStartTime(data.sessionStartTime.toDate());
	});
});

function updateUIWithSessionStartTime(date) {
	$('#session-info').text('Session started at ' + date.toLocaleString());
}