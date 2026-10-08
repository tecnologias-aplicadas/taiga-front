taiga = @.taiga

resourceProvider = ($q, $urls, $http) ->
  service = {}

  service.getDependencies = (projectId, cardType, cardRef) ->
    url = $urls.resolve("card-relations-get-all-by-ref")
    data = {
      project: projectId
      card_type: cardType
      card_ref: cardRef
    }

    return $http.get(url, data)

  service.createDependency = (projectId, sourceType, sourceId, targetType, targetId, relationType) ->
    url = $urls.resolve("card-relations")
    data = {
      project_id: projectId
      source_type: sourceType
      source_id: sourceId
      target_type: targetType
      target_id: targetId
      relation_type: relationType
    }
    return $http.post(url, data)

  service.updateDependency = (relationId, relationType) ->
    baseUrl = $urls.resolve("card-relations")
    url = "#{baseUrl}/#{relationId}"
    return $http.patch(url, {relation_type: relationType})

  service.removeDependency = (relationId) ->
    baseUrl = $urls.resolve("card-relations")
    url = "#{baseUrl}/#{relationId}"
    return $http.delete(url)

  service.resolveDependency = (relationId) ->
    baseUrl = $urls.resolve("card-relations")
    url = "#{baseUrl}/#{relationId}/resolve"
    return $http.patch(url, {})

  return (instance) ->
    instance.cardRelations = service

module = angular.module("taigaResources")
module.factory("$tgCardRelationsResourcesProvider", ["$q", "$tgUrls", "$tgHttp", resourceProvider])