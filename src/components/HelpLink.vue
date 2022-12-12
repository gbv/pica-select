<script setup>
defineProps({ href: { type: String, required: true } })
</script>

<template>
  <a :href="href" title="Hilfe" class="help-link" target="_blank">
      <small><sup>?</sup></small>
  </a>
</template> 

<style>
.help-link {
  text-decoration: none;
}
</style>
