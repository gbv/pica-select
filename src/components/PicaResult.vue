<script setup>
import { onMounted, watch, toRefs } from "vue"

import  Prism from 'prismjs'
import 'prismjs/themes/prism.css'
import "../prism-pica.js"

const props = defineProps({ records: String })

const highlight = () => Prism.highlightElement(document.getElementById("pica-result"))
onMounted(() => highlight())
watch(toRefs(props).records, highlight)
</script>

<template>
  <pre class="language-pica" id="pica-result"><code>{{records}}</code></pre>
</template>
