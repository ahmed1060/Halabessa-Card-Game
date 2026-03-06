mergeInto(LibraryManager.library, {
  PostToFlutter: function (message) {
    if (window.parent) {
      window.parent.postMessage(UTF8ToString(message), "*");
    }
  },
});
