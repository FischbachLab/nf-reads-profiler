#!/usr/bin/env python
from __future__ import print_function
from collections import OrderedDict
import re

regexes = {
    "nf-reads-profiler": ["v_pipeline.txt", r"(\S+)"],
    "Nextflow": ["v_nextflow.txt", r"(\S+)"],
    "MetaPhlAn": ["v_metaphlan.txt", r"MetaPhlAn version (\S+)"],
    "HUMAnN": ["v_humann.txt", r"humann v(\S+)"],
    "qiime": ["v_qiime.txt", r"(\S+)"],
    "MultiQC": ["v_multiqc.txt", r"(\S+)"],
}
results = OrderedDict()
results["nf-reads-profiler"] = '<span style="color:#999999;">N/A</span>'
results["Nextflow"] = '<span style="color:#999999;">N/A</span>'
results["MetaPhlAn"] = '<span style="color:#999999;">N/A</span>'
results["HUMAnN"] = '<span style="color:#999999;">N/A</span>'
results["qiime"] = '<span style="color:#999999;">N/A</span>'
results["MultiQC"] = '<span style="color:#999999;">N/A</span>'

# Search each file using its regex
for k, v in regexes.items():
    with open(v[0]) as x:
        versions = x.read()
        match = re.search(v[1], versions)
        if match:
            results[k] = "v{}".format(match.group(1))

# Dump to YAML
print(
    """
id: 'software-versions'
section_name: 'nf-reads-profiler Software Versions'
section_href: 'https://github.com/fischbachlab/nf-reads-profiler'
plot_type: 'html'
description: 'This information is collected at run time from the containers specification.'
data: |
    <dl class="dl-horizontal">
"""
)
for k, v in results.items():
    print("        <dt>{}</dt><dd>{}</dd>".format(k, v))
print("    </dl>")
