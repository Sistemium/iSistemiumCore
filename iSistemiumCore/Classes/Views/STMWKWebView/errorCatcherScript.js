// catch errors
window.addEventListener('error', function (event) {
                        
    var params = {
        'message': event.message,
        'filename': event.filename,
        'colno': event.colno,
        'lineno': event.lineno,
    };

    window.webkit.messageHandlers.errorCatcher.postMessage(params);

});
