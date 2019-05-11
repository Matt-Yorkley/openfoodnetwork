Darkswarm.controller "ProducersTabCtrl", ($scope, Shopfront, EnterpriseModal) ->
  # Injecting Enterprises so CurrentHub.producers is dereferenced.
  # We should probably dereference here instead and separate out CurrentHub dereferencing from the Enterprise factory.
  $scope.enterprise = Shopfront.shopfront
