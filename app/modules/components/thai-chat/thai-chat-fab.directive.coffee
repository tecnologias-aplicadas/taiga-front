###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

ThaiChatFabDirective = () ->
    return {
        controller: "ThaiChatCtrl",
        bindToController: true,
        scope: {},
        controllerAs: "vm",
        templateUrl: "components/thai-chat/thai-chat-fab.html"
    }

angular.module("taigaComponents").directive("tgThaiChatFab", ThaiChatFabDirective)