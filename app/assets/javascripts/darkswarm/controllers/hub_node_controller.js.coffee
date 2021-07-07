Darkswarm.controller "HubNodeCtrl", ($scope, CurrentHub, $http, $timeout) ->
  $scope.shopfront_loading = false
  $scope.enterprise_details = []
  $scope.open_tab = null

  # Toggles shopfront tabs open/closed. Fetches enterprise details from the api, diplays them and adds them
  # to $scope.enterprise_details, or simply displays the details again if previously fetched
  $scope.toggle = (event) ->
    return if event.target.closest("a")

    if $scope.open()
      $scope.open_tab = null
      return

    if $scope.enterprise_details[$scope.hub.id]
      $scope.hub = $scope.enterprise_details[$scope.hub.id]
      $scope.toggle_tab()
      return

    $scope.load_shopfront()

  $scope.load_shopfront = ->
    $scope.shopfront_loading = true
    $scope.toggle_tab()

    $http.get("/api/v0/shops/" + $scope.hub.id)
      .success (data) ->
        $scope.shopfront_loading = false
        $scope.hub = data
        $scope.enterprise_details[$scope.hub.id] = $scope.hub
      .error (data) ->
        console.error(data)

  $scope.toggle_tab = ->
    if $scope.open_tab == $scope.hub.hash
      $scope.open_tab = null
    else
      $scope.open_tab = $scope.hub.hash

  # Returns boolean: pulldown tab is currently open/closed
  $scope.open = ->
    $scope.open_tab == $scope.hub.hash

  # Returns boolean: is this hub the hub that the user is currently "shopping" in?
  $scope.current = ->
    $scope.hub.id is CurrentHub.hub?.id
