// ── FLYBY MODEL STATE CHECK ───────────────────────────────────────
// Paste into console to see which athletes have data loaded
// and what the data structure looks like for each.
// ─────────────────────────────────────────────────────────────────

(function () {
  var models = window.flyby.results.activities.models;
  console.log('Total models: ' + models.length);

  models.forEach(function (model, i) {
    var attr      = model.attributes;
    var dataModel = model.data;
    var points    = null;

    if (dataModel) {
      if (typeof dataModel.get === 'function') points = dataModel.get('data');
      if (!Array.isArray(points) && dataModel.attributes) points = dataModel.attributes.data;
    }

    var ptInfo = !points               ? 'NULL'
               : !points.length        ? 'EMPTY []'
               : points.length + ' pts  [0]:' + JSON.stringify(points[0]).slice(0, 80);

    console.log(
      '[' + i + '] ' +
      (attr.shortFirstName || attr.name || '?').padEnd(12) +
      '  id:' + model.id +
      '  fetched:' + (dataModel && dataModel.fetched ? 'yes' : 'no') +
      '  data: ' + ptInfo
    );
  });
})();
