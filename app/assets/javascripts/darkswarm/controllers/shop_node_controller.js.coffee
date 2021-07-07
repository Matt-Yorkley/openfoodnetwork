Darkswarm.controller "ShopNodeCtrl", ($scope) ->
  $scope.open_tab = null

  $scope.toggle = ->
    if $scope.open()
      $scope.open_tab = null
    else
      $scope.open_tab = $scope.shop.hash

  $scope.open = ->
    $scope.open_tab == $scope.shop.hash
