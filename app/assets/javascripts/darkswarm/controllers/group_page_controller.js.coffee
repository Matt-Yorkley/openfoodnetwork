Darkswarm.controller "GroupPageCtrl", ($scope, enterprises, Enterprises, MapConfiguration, OfnMap, visibleFilter, Navigation) ->
  $scope.Enterprises = Enterprises

  enterprises_by_id = enterprises.map (enterprise) =>
    Enterprises.enterprises_by_id[enterprise.id]

  visible_enterprises = visibleFilter enterprises_by_id

  # TODO: this is duplicate code with app/assets/javascripts/darkswarm/services/enterprises.js.coffee
  # It would be better to load only the needed enterprises (group + related shops).
  $scope.group_producers = visible_enterprises.filter (enterprise) ->
        enterprise.category in ["producer_hub", "producer_shop", "producer"]
  $scope.group_hubs = visible_enterprises.filter (enterprise) ->
        enterprise.category in ["hub", "hub_profile", "producer_hub", "producer_shop"]

  $scope.producers_to_filter = $scope.group_producers

  $scope.map = angular.copy MapConfiguration.options
  $scope.mapMarkers = OfnMap.enterprise_markers visible_enterprises
  $scope.embedded_layout = window.location.search.indexOf("embedded_shopfront=true") != -1