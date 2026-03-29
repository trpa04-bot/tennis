// version-check.js
// Auto-reload Flutter web app when version.json changes (Firebase Hosting, all browsers)
(function() {
  const VERSION_URL = 'version.json';
  let currentVersion = null;

  function checkVersion() {
    fetch(VERSION_URL, { cache: 'no-store' })
      .then(response => response.json())
      .then(data => {
        if (!currentVersion) {
          currentVersion = data;
        } else if (JSON.stringify(data) !== JSON.stringify(currentVersion)) {
          // Version changed, force reload
          window.location.reload(true);
        }
      })
      .catch(() => {});
  }

  // Initial check
  checkVersion();
  // Poll every 30 seconds
  setInterval(checkVersion, 30000);
})();
