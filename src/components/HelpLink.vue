<script setup>
defineProps({ href: { type: String, required: true } })
</script>

<template>
  <a :href="href" title="Hilfe" class="help-link" target="_blank">
    🛈 
  </a>
</template> 

<style>
.help-link {
  text-decoration: none;
  margin-left: -0.3em;
}
</style>
