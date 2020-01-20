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

// IDs of the images that we currently have displayed.
// (Firestore returns them as it receives them, and it receives them out of order.)
var currentImages = [];

// Remove all images on the page
function clearOldData() {
	$('#images').empty();
	currentImages = [];
	setBottomStickyEnabled(true);
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
				updateUIWithImage(change.doc.id,
								  data.captureTime.toDate(),
							  	  data.link,
							  	  data.message);
			}
		});
	});
}

function updateUIWithSessionStartTime(date) {
	$('#session-info').text('Session started at ' + date.toLocaleString());
}

// When true, updateUIWithImage will scroll to the bottom with every appended image
var isBottomStickyEnabled = true;

// Disable sticking when the user scrolls away from the bottom
$(window).scroll(function() {
	if($(window).scrollTop() + $(window).height() >= $(document).height()) {
		setBottomStickyEnabled(true);
	} else {
		setBottomStickyEnabled(false);
	}
});

function setBottomStickyEnabled(enabled) {
	isBottomStickyEnabled = enabled;
	if (enabled) {
		if (location.hash != '#latest') {
			location.href = '#latest';
		}
	} else {
		if (location.hash == '#latest') {
			history.pushState(null, null, ' ');
		}
	}
}

function updateUIWithImage(id, date, link, message) {
	var html = '<div id="' + id + '" class="row"><div class="col-xs-9 center-xs"><img src="' + link + '" alt="' + message + '"></div><div class="col-xs"><p>' + message + '</p><p>Logged at ' + date.toLocaleString() + '</p><p><a href="' + link + '">Download</a></p></div></div>';
	var idInt = parseInt(id);
	if (idInt == 0) {
		// First image goes to the top of #images
		currentImages.unshift(0);
		$('#images').prepend(html);
	} else if (currentImages.length == 0) {
		// Not the first image but we don't have any images yet, so insert it anywhere
		currentImages.push(idInt);
		$('#images').append(html);
	} else {
		// Guaranteed to have at least one image in the array, so add this one in its correct position
		currentImages.splice(locationOf(idInt, currentImages) + 1, 0, idInt);

		// Find its index
		var idx = currentImages.indexOf(idInt);
		if (idx > 0) {
			// Find the previous ID
			var lastID = currentImages[idx - 1];

			// And insert our image in the UI after it
			$('#' + lastID).after(html);
		} else {
			// Not image 0 but its slot is currently 0
			$('#images').prepend(html);
		}
	}

	// Scroll to new bottom
	if (isBottomStickyEnabled) {
		location.href = '#latest';
	}
}

// Fast sorted array insertion
function locationOf(element, array, start, end) {
	start = start || 0;
	end = end || array.length;
	var pivot = parseInt(start + (end - start) / 2, 10);
	if (array[pivot] === element) return pivot;
	if (end - start <= 1)
		return array[pivot] > element ? pivot - 1 : pivot;
	if (array[pivot] < element) {
		return locationOf(element, array, pivot, end);
	} else {
		return locationOf(element, array, start, pivot);
	}
}