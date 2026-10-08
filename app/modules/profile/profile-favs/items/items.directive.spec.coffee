###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "favItemDirective", () ->
    scope = compile = provide = null
    template = "<div tg-fav-item='item' item-type='userstory'></div>"

    createDirective = () ->
        elm = compile(template)(scope)
        return elm

    _mockTranslateFilter = () ->
        mockTranslateFilter = (value) ->
            return value
        provide.value "translateFilter", mockTranslateFilter

    _mockEmojifyFilter = () ->
        mockEmojifyFilter = (value) ->
            return value
        provide.value "emojifyFilter", mockEmojifyFilter

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTranslateFilter()
            _mockEmojifyFilter()
            return null

    beforeEach ->
        module "templates"
        module "taigaProfile"

        _mocks()

        inject ($rootScope, $compile) ->
            scope = $rootScope.$new()
            compile = $compile

    _compileItem = (item) ->
        scope.item = Immutable.fromJS(item)
        elm = createDirective()
        scope.$apply()
        return elm.isolateScope().vm

    it "show the first of the assigned users for a user story", () ->
        vm = _compileItem({
            type: "userstory"
            ref: 1
            assigned_to: 9
            assigned_to_extra_info: {id: 9, username: "single", full_name_display: "Single field"}
            assigned_users_extra_info: [
                {id: 2, username: "member2", full_name_display: "Member 2"},
                {id: 5, username: "member5", full_name_display: "Member 5"}
            ]
        })

        expect(vm.getAssignedUser().get('id')).to.be.equal(2)
        expect(vm.getAssignedUser().get('username')).to.be.equal("member2")

    it "show nobody for a user story without assigned users even if assigned_to is present", () ->
        vm = _compileItem({
            type: "userstory"
            ref: 1
            assigned_to: 9
            assigned_to_extra_info: {id: 9, username: "single", full_name_display: "Single field"}
            assigned_users_extra_info: []
        })

        expect(vm.getAssignedUser()).to.be.null

    it "keep assigned_to_extra_info for a task", () ->
        vm = _compileItem({
            type: "task"
            ref: 1
            assigned_to: 9
            assigned_to_extra_info: {id: 9, username: "single", full_name_display: "Single field"}
            assigned_users_extra_info: []
        })

        expect(vm.getAssignedUser().get('id')).to.be.equal(9)

    it "count no extra assignees with a single assigned user", () ->
        vm = _compileItem({
            type: "userstory"
            ref: 1
            assigned_users_extra_info: [{id: 2}]
        })

        expect(vm.getExtraAssigneesCount()).to.be.equal(0)

    it "count one extra assignee with two assigned users", () ->
        vm = _compileItem({
            type: "userstory"
            ref: 1
            assigned_users_extra_info: [{id: 2}, {id: 5}]
        })

        expect(vm.getExtraAssigneesCount()).to.be.equal(1)

    it "count two extra assignees with three assigned users", () ->
        vm = _compileItem({
            type: "userstory"
            ref: 1
            assigned_users_extra_info: [{id: 2}, {id: 5}, {id: 7}]
        })

        expect(vm.getExtraAssigneesCount()).to.be.equal(2)

    it "count no extra assignees for a task", () ->
        vm = _compileItem({
            type: "task"
            ref: 1
            assigned_to_extra_info: {id: 9}
            assigned_users_extra_info: [{id: 2}, {id: 5}, {id: 7}]
        })

        expect(vm.getExtraAssigneesCount()).to.be.equal(0)

    it "show nobody for an issue without assigned_to_extra_info", () ->
        vm = _compileItem({
            type: "issue"
            ref: 1
            assigned_to: null
            assigned_to_extra_info: null
            assigned_users_extra_info: []
        })

        expect(vm.getAssignedUser()).to.be.null
