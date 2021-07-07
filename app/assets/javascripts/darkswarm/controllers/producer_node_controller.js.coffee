Darkswarm.controller "ProducerNodeCtrl", ($scope, $http, $timeout) ->
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

    if $scope.enterprise_details[$scope.producer.id]
      $scope.producer = $scope.enterprise_details[$scope.producer.id]
      $scope.toggle_tab()
      return

    $scope.load_shopfront()

  $scope.load_shopfront = ->
    $scope.shopfront_loading = true
    $scope.toggle_tab()

    $http.get("/api/v0/shops/" + $scope.producer.id)
      .success (data) ->
        $scope.shopfront_loading = false
        $scope.producer = data
        $scope.enterprise_details[$scope.producer.id] = $scope.producer
      .error (data) ->
        console.error(data)

  $scope.toggle_tab = ->
    if $scope.open_tab == $scope.producer.hash
      $scope.open_tab = null
    else
      $scope.open_tab = $scope.producer.hash

  $scope.open = ->
    $scope.open_tab == $scope.producer.hash
