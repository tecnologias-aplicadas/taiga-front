###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "CommentsController", ->
    provide = null
    controller = null
    scope = null
    mocks = {}

    _mockTgHttp = () ->
        mocks.tgHttp = {
            get: sinon.stub()
            post: sinon.stub()
        }
        provide.value "$tgHttp", mocks.tgHttp

    _mockTgUrls = () ->
        mocks.tgUrls = {
            resolve: sinon.stub()
        }
        provide.value "$tgUrls", mocks.tgUrls

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgHttp()
            _mockTgUrls()
            return null

    beforeEach ->
        module "taigaHistory"
        _mocks()

        inject ($controller, $rootScope) ->
            controller = $controller
            scope = $rootScope.$new()

    it "set can add comment permission", () ->
        commentsCtrl = controller "CommentsCtrl", {$scope: scope}
        commentsCtrl.name = "us"
        commentsCtrl.initializePermissions()
        expect(commentsCtrl.canAddCommentPermission).to.be.equal("comment_us")

    it "load reactions only once when the comments arrive", () ->
        commentsCtrl = controller "CommentsCtrl", {$scope: scope}
        mocks.tgUrls.resolve.returns("/comments/reactions")
        mocks.tgHttp.get.promise()

        commentsCtrl.comments = [{id: 1}, {id: 2}]
        scope.$digest()
        expect(mocks.tgHttp.get.callCount).to.be.equal(2)

        commentsCtrl.comments = [{id: 1}, {id: 2}, {id: 3}]
        scope.$digest()
        expect(mocks.tgHttp.get.callCount).to.be.equal(2)
