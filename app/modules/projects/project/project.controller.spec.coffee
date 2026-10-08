###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "ProjectController", ->
    $controller = null
    $q = null
    provide = null
    $rootScope = null
    mocks = {}

    _mockProjectService = () ->
        mocks.projectService = {}

        provide.value "tgProjectService", mocks.projectService

    _mockConfigService = () ->
        mocks.configService = {
            get: sinon.stub()
        }

        provide.value "$tgConfig", mocks.configService

    _mockNavUrlsService = () ->
        mocks.navUrlsService = {
            resolve: sinon.stub()
        }

        provide.value "$tgNavUrls", mocks.navUrlsService

    _mockAppMetaService = () ->
        mocks.appMetaService = {
            setfn: sinon.stub()
        }

        provide.value "tgAppMetaService", mocks.appMetaService

    _mockAuth = () ->
        mocks.auth = {
            userData: Immutable.fromJS({username: "UserName"})
        }

        provide.value "$tgAuth", mocks.auth

    _mockRouteParams = () ->
        provide.value "$routeParams", {
            pslug: "project-slug"
        }

    _mockTranslate = () ->
        mocks.translate = {}
        mocks.translate.instant = sinon.stub()

        provide.value "$translate", mocks.translate

    _mockHttp = () ->
        mocks.http = {
            get: sinon.stub().promise()
        }

        provide.value "$tgHttp", mocks.http

    _mockUrls = () ->
        mocks.urls = {
            resolve: sinon.stub()
        }

        provide.value "$tgUrls", mocks.urls

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockProjectService()
            _mockConfigService()
            _mockNavUrlsService()
            _mockRouteParams()
            _mockAppMetaService()
            _mockAuth()
            _mockTranslate()
            _mockHttp()
            _mockUrls()
            return null

    _inject = (callback) ->
        inject (_$controller_, _$q_, _$rootScope_) ->
            $q = _$q_
            $rootScope = _$rootScope_
            $controller = _$controller_

    beforeEach ->
        module "taigaProjects"
        _mocks()
        _inject()

    it "set local user", () ->
        project = Immutable.fromJS({
            name: "projectName"
            members: []
        })

        ctrl = $controller "Project",
            $scope: {}

        expect(ctrl.user).to.be.equal(mocks.auth.userData)

    it "set page title", () ->
        $scope = $rootScope.$new()
        project = Immutable.fromJS({
            name: "projectName"
            description: "projectDescription",
            members: []
        })

        mocks.translate.instant
            .withArgs('PROJECT.PAGE_TITLE', {
                projectName: project.get("name")
            })
            .returns('projectTitle')

        mocks.projectService.project = project

        ctrl = $controller("Project")

        metas = ctrl._setMeta(project)

        expect(metas.title).to.be.equal('projectTitle')
        expect(metas.description).to.be.equal('projectDescription')
        expect(mocks.appMetaService.setfn).to.be.calledOnce

    it "set local project variable and members", () ->
        project = Immutable.fromJS({
            name: "projectName"
        })

        members = Immutable.fromJS([
            {is_active: true},
            {is_active: true},
            {is_active: true}
        ])

        mocks.projectService.project = project
        mocks.projectService.activeMembers = members

        ctrl = $controller("Project")

        expect(ctrl.project).to.be.equal(project)
        expect(ctrl.members).to.be.equal(members)

    it "decorate project dates", () ->
        mocks.projectService.project = Immutable.fromJS({
            id: 3
            name: "projectName"
            start_date: "2026-01-01"
            expected_end_date: "2026-12-31"
            end_date: null
        })

        ctrl = $controller("Project")

        expect(ctrl.dates.start).to.be.equal("01/01/2026")
        expect(ctrl.dates.expectedEnd).to.be.equal("31/12/2026")
        expect(ctrl.dates.end).to.be.equal("--/--/----")
        expect(ctrl.isActiveProject).to.be.true
        expect(ctrl.totalDays).to.be.equal(364)

    it "load schedulable bar from epics history", (done) ->
        mocks.projectService.project = Immutable.fromJS({
            id: 3
            name: "projectName"
        })
        mocks.urls.resolve.withArgs("epics").returns("/epics")

        ctrl = $controller("Project")

        expect(mocks.http.get).to.be.calledWith("/epics/history_pd", {project: 3})

        mocks.http.get.resolve({data: {monthly: [
            {has_snapshot: true, scheduled_impact_done: 40, unscheduled_impact_done: 10}
        ]}})

        mocks.http.get.firstCall.returnValue.then () ->
            expect(ctrl.schedulableBars.length).to.be.equal(2)
            expect(ctrl.schedulableBars[0].value).to.be.equal("40%")
            expect(ctrl.schedulableBars[1].value).to.be.equal("10%")
            done()
