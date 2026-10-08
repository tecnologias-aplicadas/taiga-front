###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

# Rastreia os campos em edição na tela aberta. As telas de detalhe consultam
# `isEditing()` ao receber evento do servidor e adiam a recarga silenciosa;
# quando o último campo sai de edição, o serviço avisa com `editing:idle`.
class EditingTrackerService extends taiga.Service
    @.$inject = ["$rootScope"]

    constructor: (@rootScope) ->
        @.keys = {}
        @rootScope.$on "$routeChangeSuccess", => @.reset()

    begin: (key) ->
        @.keys[key] = true

    end: (key) ->
        return if not @.keys[key]
        delete @.keys[key]
        @rootScope.$broadcast("editing:idle") if not @.isEditing()

    isEditing: () ->
        return Object.keys(@.keys).length > 0

    reset: () ->
        @.keys = {}

angular.module("taigaComponents").service("tgEditingTracker", EditingTrackerService)
