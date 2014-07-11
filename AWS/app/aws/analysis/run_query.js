analysis_mod.controller("RunQueryCtrl", function($scope, queryService) {

	$scope.runQuery = function() {
		queryHandler = new aws.QueryHandler(queryService.queryObject);
		
		console.log(queryService.queryObject);
		// doesn't work to remove weave instance -> $scope.weaveInstancePanel = "";
		// Probably need to put a broadcast event here? to tell weave instance panel to die.
		queryHandler.runQuery();
	};

	$scope.updateVisualizations = function() {
		if (queryHandler) {
			queryHandler.updateVisualizations(queryService.queryObject);
		}
	};

	$scope.clearWeave = function() {
		if (queryHandler != undefined) {
			queryHandler.clearWeave();
		}
	};
});

analysis_mod.controller("ColorColumnCtrl", function($scope, queryService) {

	$scope.service = queryService;

});

analysis_mod.controller("QueryImportExportCtrl", function($scope, queryService) {

	$scope.exportQueryObject = function() {
		var blob = new Blob([JSON.stringify(queryService.queryObject, undefined, 2)], {
			type : "text/plain;charset=utf-8"
		});
		saveAs(blob, "QueryObject.json");
	};

	$scope.importQueryObject = function() {
	};

	$scope.$on('fileUploaded', function(e) {
		$scope.$safeApply(function() {
			queryService.queryObject = e.targetScope.file;
		});
	});

});


function saveJSON(query) {
	var blob = new Blob([ JSON.stringify(query, undefined, 2) ], {
		type : "text/plain;charset=utf-8"
	});
	saveAs(blob, "QueryObject.json");
}