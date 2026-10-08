###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "HomeLandingController", ->
    provide = controller = null
    mocks = {}

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            mocks.currentUserService = {getUser: sinon.stub().returns(null)}
            mocks.location = {path: sinon.stub()}
            mocks.navUrls = {resolve: sinon.stub()}

            provide.value "tgCurrentUserService", mocks.currentUserService
            provide.value "$location", mocks.location
            provide.value "$tgNavUrls", mocks.navUrls
            return null

    beforeEach ->
        module "taigaHome"
        _mocks()
        inject ($controller) ->
            controller = $controller

    createController = () ->
        controller "HomeLanding", {$scope: {}}

    it "visitante fica na home pública, sem redirecionamento", () ->
        createController()
        expect(mocks.location.path.callCount).to.be.equal(0)

    it "usuário autenticado é redirecionado para os projetos", () ->
        mocks.currentUserService.getUser.returns({id: 1})
        mocks.navUrls.resolve.withArgs("projects").returns("projects")
        createController()
        expect(mocks.location.path).to.be.calledWith("projects")
