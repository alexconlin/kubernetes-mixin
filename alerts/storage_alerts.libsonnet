{
  _config+:: {
    kubeStateMetricsSelector: error 'must provide selector for kube-state-metrics',
    kubeletSelector: error 'must provide selector for kubelet',
    namespaceSelector: null,
    prefixedNamespaceSelector: if self.namespaceSelector != null then self.namespaceSelector + ',' else '',

    // We alert when a disk is expected to fill up in four days. Depending on
    // the data-set it might be useful to change the sampling-time for the
    // prediction
    volumeFullPredictionSampleTime: '6h',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-storage',
        rules: [
          {
            alert: 'KubePersistentVolumeUsageCritical',
            expr: |||
              kubelet_volume_stats_available_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
                /
              kubelet_volume_stats_capacity_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
                < 0.03
            ||| % $._config,
            'for': '1m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'The PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} is only {{ $value | humanizePercentage }} free.',
            },
          },
          {
            alert: 'KubePersistentVolumeFullInFourDays',
            expr: |||
              (
                kubelet_volume_stats_available_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
                  /
                kubelet_volume_stats_capacity_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
              ) < 0.15
              and
              predict_linear(kubelet_volume_stats_available_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}[%(volumeFullPredictionSampleTime)s], 4 * 24 * 3600) < 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'Based on recent sampling, the PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} is expected to fill up within four days. Currently {{ $value | humanizePercentage }} is available.',
            },
          },
          {
            alert: 'KubePersistentVolumeErrors',
            expr: |||
              kube_persistentvolume_status_phase{phase=~"Failed|Pending",%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'The persistent volume {{ $labels.persistentvolume }} has status {{ $labels.phase }}.',
            },
          },
        ],
      },
    ],
  },
}
