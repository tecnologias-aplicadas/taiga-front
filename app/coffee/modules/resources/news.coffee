###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

# Recurso do carrossel de novidades (/api/v1/news).
# Leitura é pública; escrita só de superusuário (o servidor decide).

NEWS_SLIDE_MAX_IMAGE_SIZE = 2 * 1024 * 1024

resourceProvider = ($http, $urls, $q) ->
    service = {}

    service.NEWS_SLIDE_MAX_IMAGE_SIZE = NEWS_SLIDE_MAX_IMAGE_SIZE

    multipartOptions = {
        transformRequest: angular.identity,
        headers: {'Content-Type': undefined}
    }

    rejectTooLarge = () ->
        defered = $q.defer()
        defered.reject({status: 413, data: {image: ["image_too_large"]}})
        return defered.promise

    service.list = () ->
        return $http.get($urls.resolve("news")).then (response) -> response.data

    service.create = (data, file) ->
        return rejectTooLarge() if file and file.size > NEWS_SLIDE_MAX_IMAGE_SIZE

        formData = new FormData()
        formData.append('image', file) if file
        for key, value of data when value?
            formData.append(key, value)

        return $http.post($urls.resolve("news"), formData, {}, multipartOptions).then (response) -> response.data

    service.update = (slideId, data) ->
        url = "#{$urls.resolve("news")}/#{slideId}"
        return $http.patch(url, data).then (response) -> response.data

    service.changeImage = (slideId, file) ->
        return rejectTooLarge() if file.size > NEWS_SLIDE_MAX_IMAGE_SIZE

        formData = new FormData()
        formData.append('image', file)
        url = "#{$urls.resolve("news")}/#{slideId}"
        return $http.patch(url, formData, {}, multipartOptions).then (response) -> response.data

    service.remove = (slideId) ->
        url = "#{$urls.resolve("news")}/#{slideId}"
        return $http.delete(url)

    service.bulkUpdateOrder = (items) ->
        return $http.post($urls.resolve("news-bulk-update-order"), items)

    return (instance) ->
        instance.news = service


module = angular.module("taigaResources")
module.factory("$tgNewsResourcesProvider", ["$tgHttp", "$tgUrls", "$q", resourceProvider])
