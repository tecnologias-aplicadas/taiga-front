###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

MIN_COL_W = 44  # pixels mínimos por mês antes de ativar scroll

ScheduleChartsCtrl = (epicsService, $rootScope, $timeout, $filter) ->
    t = (key) -> $filter('translate')(key)
    vm = @

    vm.pdOpen = false
    vm.el     = null
    vm.dataLoaded    = false
    vm.totalSched    = 0
    vm.totalUnsched  = 0
    vm.pdStatSched   = 0
    vm.pdStatUnsched = 0
    vm.pdDoneSched   = 0
    vm.pdDoneUnsched = 0

    _chartInstance = null

    vm.buildChart = (canvas, barLabels, schedData, unschedData, totalImpact, todayBarIdx, expectedEndIdx = -1) ->
        return unless canvas

        n          = barLabels.length
        containerW = canvas.parentElement?.clientWidth or 760
        canvasW    = Math.max(containerW, n * MIN_COL_W)
        canvasH    = 260
        dpr        = window.devicePixelRatio or 1

        canvas.width  = canvasW * dpr
        canvas.height = canvasH * dpr
        canvas.style.width  = canvasW + 'px'
        canvas.style.height = canvasH + 'px'
        canvas.parentElement.style.width = canvasW + 'px'

        # Destroy previous instance if exists
        if _chartInstance
            _chartInstance.destroy()
            _chartInstance = null

        # TMP data snapshot (captured at build time)
        tmpData = vm.dataPD.map (d) -> { isTmp: d.isTmp, tmpChanges: d.tmpChanges }
        BAND_COLORS = ['rgba(240,244,255,0.45)', 'rgba(255,248,235,0.45)']

        # Plugin para faixas TMP, linha vertical "hoje" e separadores de ano
        todayLinePlugin =
            id: 'todayLine'

            beforeDraw: (chart) ->
                ctx   = chart.ctx
                xAxis = chart.scales.x
                yAxis = chart.scales.y
                top    = yAxis.top
                bottom = yAxis.bottom
                nb     = chart.data.labels.length
                colW   = xAxis.width / nb

                currentBand = 0
                for i in [0...nb]
                    if i > 0 and tmpData[i]?.isTmp
                        currentBand = 1 - currentBand
                    xCenter = xAxis.getPixelForValue(i)
                    xLeft   = if i is 0      then xAxis.left  else xCenter - colW / 2
                    xRight  = if i is nb - 1 then xAxis.right else xCenter + colW / 2

                    # Overdue columns (after expected end date) get a warm reddish tint
                    if expectedEndIdx >= 0 and i > expectedEndIdx
                        ctx.save()
                        ctx.fillStyle = 'rgba(210,90,80,0.2)'
                        ctx.fillRect(xLeft, top, xRight - xLeft, bottom - top)
                        ctx.restore()
                    else
                        ctx.save()
                        ctx.fillStyle = BAND_COLORS[currentBand]
                        ctx.fillRect(xLeft, top, xRight - xLeft, bottom - top)
                        ctx.restore()

            afterDatasetsDraw: (chart) ->
                ctx = chart.ctx
                ctx.save()
                ctx.font      = '11px Ubuntu, Arial, sans-serif'
                ctx.fillStyle = 'white'
                ctx.textAlign = 'center'
                ctx.textBaseline = 'middle'
                for dsIdx in [0, 1]
                    meta = chart.getDatasetMeta(dsIdx)
                    continue unless meta?.data
                    for bar, i in meta.data
                        h = bar.height
                        w = bar.width
                        continue unless h > 18 and w > 20
                        val = chart.data.datasets[dsIdx].data[i]
                        continue unless val > 0
                        label = '' + (Math.round(val * 10) / 10)
                        ctx.fillText(label, bar.x, bar.y + h / 2)
                ctx.restore()

            afterDraw: (chart) ->
                ctx   = chart.ctx
                xAxis = chart.scales.x
                yAxis = chart.scales.y
                top    = yAxis.top
                bottom = yAxis.bottom

                # "Hoje" marker
                if todayBarIdx >= 0 and todayBarIdx < chart.data.labels.length
                    x = xAxis.getPixelForValue(todayBarIdx)
                    ctx.save()
                    ctx.beginPath()
                    ctx.setLineDash([4, 4])
                    ctx.strokeStyle = '#D8DEE9'
                    ctx.lineWidth   = 1
                    ctx.moveTo(x, top)
                    ctx.lineTo(x, bottom)
                    ctx.stroke()
                    ctx.setLineDash([])
                    ctx.fillStyle = '#A9AABC'
                    ctx.font      = '11px Ubuntu, Arial, sans-serif'
                    ctx.textAlign = 'center'
                    ctx.fillText('hoje', x, top - 4)
                    ctx.restore()

                # Year separators at January
                months = chart.data.monthKeys or []
                colW   = xAxis.width / chart.data.labels.length
                for ym, i in months
                    if ym?.endsWith('-01')
                        x    = xAxis.getPixelForValue(i) - colW / 2
                        year = ym.split('-')[0]
                        ctx.save()
                        ctx.beginPath()
                        ctx.strokeStyle = '#C6C6D4'
                        ctx.lineWidth   = 1
                        ctx.moveTo(x, top)
                        ctx.lineTo(x, bottom)
                        ctx.stroke()
                        ctx.fillStyle = '#A9AABC'
                        ctx.font      = '10px Ubuntu, Arial, sans-serif'
                        ctx.textAlign = 'left'
                        ctx.fillText(year, x + 3, top + 12)
                        ctx.restore()

                # TMP vertical dashed lines
                for d, i in tmpData
                    continue unless d?.isTmp
                    x = xAxis.getPixelForValue(i)
                    ctx.save()
                    ctx.beginPath()
                    ctx.setLineDash([4, 4])
                    ctx.strokeStyle = '#F59E0B'
                    ctx.lineWidth   = 1.5
                    ctx.moveTo(x, top)
                    ctx.lineTo(x, bottom)
                    ctx.stroke()
                    ctx.setLineDash([])
                    ctx.fillStyle = '#F59E0B'
                    ctx.font      = 'bold 9px Ubuntu, Arial, sans-serif'
                    ctx.textAlign = 'center'
                    ctx.fillText('TMP', x, top - 4)
                    ctx.restore()


        # Past vs future opacity — if todayBarIdx is -1 (project finished), all bars are full opacity
        isPast = (i) -> todayBarIdx < 0 or i <= todayBarIdx
        schedColors   = schedData.map  (v, i) -> if isPast(i) then 'rgba(105,148,234,1)' else 'rgba(105,148,234,0.3)'
        unschedColors = unschedData.map (v, i) -> if isPast(i) then 'rgba(202,129,190,1)' else 'rgba(202,129,190,0.3)'

        _chartInstance = new Chart(canvas, {
            type: 'bar'
            data: {
                labels:    barLabels
                monthKeys: []  # will be set below
                datasets: [
                    {
                        label:           t('EPICS.TABLE.CHART_DATASET_SCHED')
                        data:            schedData
                        backgroundColor: schedColors
                        borderRadius:    3
                        stack:           'impact'
                    }
                    {
                        label:           t('EPICS.TABLE.CHART_DATASET_UNSCHED')
                        data:            unschedData
                        backgroundColor: unschedColors
                        borderRadius:    3
                        stack:           'impact'
                    }
                ]
            }
            options: {
                responsive:          false
                maintainAspectRatio: false
                devicePixelRatio:    dpr
                animation:           { duration: 600, easing: 'easeOutQuart' }
                plugins: {
                    legend: { display: false }
                    tooltip: {
                        mode:       'index'
                        intersect:  false
                        bodyFont:   { size: 13, family: 'Ubuntu, Arial, sans-serif' }
                        titleFont:  { size: 13, family: 'Ubuntu, Arial, sans-serif', weight: '600' }
                        footerFont: { size: 11, family: 'Ubuntu, Arial, sans-serif', style: 'italic' }
                        footerColor: '#F59E0B'
                        padding:    10
                        callbacks: {
                            title: (items) -> items[0]?.label or ''
                            label: (item) ->
                                val = Math.round(item.raw * 10) / 10
                                "#{item.dataset.label}: #{val}"
                            footer: (items) ->
                                i = items[0]?.dataIndex
                                return [] unless i?
                                d = tmpData[i]
                                return [] unless d?.isTmp and d.tmpChanges?.length
                                d.tmpChanges.map (c) ->
                                    switch c.type
                                        when 'changed'
                                            t('EPICS.TABLE.TMP_CHANGE_CHANGED')
                                                .replace('__ref__',  c.ref)
                                                .replace('__from__', c.from)
                                                .replace('__to__',   c.to)
                                        when 'added'
                                            t('EPICS.TABLE.TMP_CHANGE_ADDED')
                                                .replace('__ref__', c.ref)
                                        when 'removed'
                                            t('EPICS.TABLE.TMP_CHANGE_REMOVED')
                                                .replace('__ref__', c.ref)
                                        else c
                        }
                    }
                }
                scales: {
                    x: {
                        stacked: true
                        grid:    { display: false }
                        ticks: {
                            color: '#C6C6D4'
                            font:  { family: 'Ubuntu, Arial, sans-serif', size: 11 }
                            maxRotation: 0
                        }
                    }
                    y: {
                        stacked: true
                        max:     totalImpact
                        grid:    {
                            color: (ctx) ->
                                if ctx.tick.value is totalImpact then '#C6C6D4' else '#E2E3E9'
                        }
                        ticks: {
                            color:     '#A9AABC'
                            font:      { family: 'Ubuntu, Arial, sans-serif', size: 11 }
                            stepSize:  Math.ceil(totalImpact / 4)
                            callback:  (val) -> val
                        }
                    }
                }
            }
            plugins: [todayLinePlugin]
        })

        # Store month keys for year separator plugin
        _chartInstance.data.monthKeys = vm.dataPD.slice(1).map (d) -> d.month
        _chartInstance.update()

    # ── Data loading ──────────────────────────────────────────────────────────
    vm.loadData = () ->
        return epicsService.fetchPdHistory()
            .then (response) ->
                rows = response.monthly

                now = new Date()
                currentYM = "#{now.getFullYear()}-#{String(now.getMonth() + 1).padStart(2, '0')}"

                labels   = []
                dataPD   = []
                todayIdx = 0

                lastDataIdx     = 0
                expectedEndIdx  = -1
                expectedEndYM   = response.expected_end_date or null

                monthNames = t('EPICS.TABLE.CHART_MONTH_NAMES').split(',')

                rows.forEach (row, i) ->
                    [year, mon] = row.month.split('-')
                    labels.push monthNames[parseInt(mon, 10) - 1]
                    dataPD.push {
                        sched:       row.scheduled_impact_done
                        unsched:     row.unscheduled_impact_done
                        schedDone:   row.scheduled_done
                        unschedDone: row.unscheduled_done
                        month:       row.month
                        isTmp:       row.is_tmp
                        tmpChanges:  row.tmp_changes or []
                    }
                    if row.has_snapshot
                        lastDataIdx = i
                    if row.month is currentYM
                        todayIdx = i
                    if expectedEndYM and row.month is expectedEndYM
                        expectedEndIdx = i

                # Se o mês atual não está no range do gráfico, não exibe linha "hoje"
                if todayIdx is 0 and dataPD.length > 0 and dataPD[0].month isnt currentYM
                    todayIdx = -1

                totalImpact = response.total_impact or 1

                # Use last month with real snapshot data for header stats
                statsIdx = lastDataIdx

                vm.labels        = labels
                vm.dataPD        = dataPD
                vm.totalImpact   = totalImpact
                vm.todayIdx      = todayIdx
                vm.totalSched    = response.total_scheduled
                vm.totalUnsched  = response.total_unscheduled
                vm.pdDoneSched   = dataPD[statsIdx]?.schedDone   or 0
                vm.pdDoneUnsched = dataPD[statsIdx]?.unschedDone or 0
                vm.pdStatSched   = Math.round(dataPD[statsIdx]?.sched   or 0)
                vm.pdStatUnsched = Math.round(dataPD[statsIdx]?.unsched or 0)

                if vm.totalSched > 0
                    $timeout ->
                        canvas = vm.el?.querySelector('canvas[data-chart="pd"]')
                        return unless canvas
                        schedData   = dataPD.map (d) -> d.sched
                        unschedData = dataPD.map (d) -> d.unsched
                        vm.buildChart(canvas, labels, schedData, unschedData, totalImpact, todayIdx, expectedEndIdx)
            .finally ->
                vm.dataLoaded = true

    $rootScope.$on 'epic:updated', ->
        vm.loadData()

    return

ScheduleChartsCtrl.$inject = ['tgEpicsService', '$rootScope', '$timeout', '$filter']

angular.module('taigaEpics').controller('ScheduleChartsCtrl', ScheduleChartsCtrl)
