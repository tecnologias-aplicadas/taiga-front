###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "dutyDirective", () ->
    scope = compile = provide = null
    mockTgProjectsService = null
    mockTgNavUrls = null
    mockTranslate = null
    template = "<div tg-duty='duty'></div>"

    createDirective = () ->
        elm = compile(template)(scope)
        return elm

    _mockTgNavUrls = () ->
        mockTgNavUrls = {
            resolve: sinon.stub()
        }
        provide.value "$tgNavUrls", mockTgNavUrls

    _mockTranslateFilter = () ->
        mockTranslateFilter = (value) ->
            return value
        provide.value "translateFilter", mockTranslateFilter

    _mockEmojifyFilter = () ->
        mockEmojifyFilter = (value) ->
            return value
        provide.value "emojifyFilter", mockEmojifyFilter

    _mockTgProjectsService = () ->
        mockTgProjectsService = {
            projectsById: {
                get: sinon.stub()
            }
        }
        provide.value "tgProjectsService", mockTgProjectsService

    _mockTranslate = () ->
        mockTranslate = {
            instant: sinon.stub()
        }
        provide.value "$translate", mockTranslate

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTgNavUrls()
            _mockTgProjectsService()
            _mockTranslate()
            _mockTranslateFilter()
            _mockEmojifyFilter()
            return null

    beforeEach ->
        module "templates"
        module "taigaHome"

        _mocks()

        inject ($rootScope, $compile) ->
            scope = $rootScope.$new()
            compile = $compile

    it "duty directive scope content", () ->
        scope.duty = Immutable.fromJS({
            project: 1
            ref: 1
            _name: "userstories"
            assigned_to_extra_info: {
                photo: "http://jstesting.taiga.io/photo"
                full_name_display: "Taiga testing js"
            }
        })

        mockTgProjectsService.projectsById.get
            .withArgs("1")
            .returns({slug: "project-slug", "name": "testing js project"})

        mockTgNavUrls.resolve
            .withArgs("project-userstories-detail", {project: "project-slug", ref: 1})
            .returns("http://jstesting.taiga.io")

        mockTranslate.instant
            .withArgs("COMMON.USER_STORY")
            .returns("User story translated")

        elm = createDirective()
        scope.$apply()

        expect(elm.isolateScope().vm.getDutyType()).to.be.equal("User story translated")

    describe "assigned user shown for the duty", () ->
        _compileDuty = (duty) ->
            scope.duty = Immutable.fromJS(duty)
            mockTgProjectsService.projectsById.get
                .withArgs("1")
                .returns({slug: "project-slug", "name": "testing js project"})
            elm = createDirective()
            scope.$apply()
            return elm.isolateScope().vm

        it "show the first of the assigned users for a user story", () ->
            vm = _compileDuty({
                project: 1
                ref: 1
                _name: "userstories"
                assigned_to_extra_info: {id: 9, full_name_display: "Single field"}
                assigned_users_extra_info: [
                    {id: 2, full_name_display: "Member 2"},
                    {id: 5, full_name_display: "Member 5"}
                ]
            })

            expect(vm.getAssignedUser().get('id')).to.be.equal(2)
            expect(vm.getAssignedUser().get('full_name_display')).to.be.equal("Member 2")

        it "show nobody for a user story without assigned users even if assigned_to_extra_info is present", () ->
            vm = _compileDuty({
                project: 1
                ref: 1
                _name: "userstories"
                assigned_to_extra_info: {id: 9, full_name_display: "Single field"}
                assigned_users_extra_info: []
            })

            expect(vm.getAssignedUser()).to.be.null

        it "show nobody for a user story when the list is missing", () ->
            vm = _compileDuty({
                project: 1
                ref: 1
                _name: "userstories"
                assigned_to_extra_info: {id: 9, full_name_display: "Single field"}
            })

            expect(vm.getAssignedUser()).to.be.null

        it "keep assigned_to_extra_info for a task", () ->
            vm = _compileDuty({
                project: 1
                ref: 1
                _name: "tasks"
                assigned_to_extra_info: {id: 9, full_name_display: "Single field"}
            })

            expect(vm.getAssignedUser().get('id')).to.be.equal(9)

        it "count no extra assignees with a single assigned user", () ->
            vm = _compileDuty({
                project: 1
                ref: 1
                _name: "userstories"
                assigned_users_extra_info: [{id: 2}]
            })

            expect(vm.getExtraAssigneesCount()).to.be.equal(0)

        it "count one extra assignee with two assigned users", () ->
            vm = _compileDuty({
                project: 1
                ref: 1
                _name: "userstories"
                assigned_users_extra_info: [{id: 2}, {id: 5}]
            })

            expect(vm.getExtraAssigneesCount()).to.be.equal(1)

        it "count two extra assignees with three assigned users", () ->
            vm = _compileDuty({
                project: 1
                ref: 1
                _name: "userstories"
                assigned_users_extra_info: [{id: 2}, {id: 5}, {id: 7}]
            })

            expect(vm.getExtraAssigneesCount()).to.be.equal(2)

        it "count no extra assignees for a task", () ->
            vm = _compileDuty({
                project: 1
                ref: 1
                _name: "tasks"
                assigned_to_extra_info: {id: 9}
                assigned_users_extra_info: [{id: 2}, {id: 5}, {id: 7}]
            })

            expect(vm.getExtraAssigneesCount()).to.be.equal(0)

        it "show nobody for a task without assigned_to_extra_info", () ->
            vm = _compileDuty({
                project: 1
                ref: 1
                _name: "tasks"
                assigned_to_extra_info: null
            })

            expect(vm.getAssignedUser()).to.be.null
