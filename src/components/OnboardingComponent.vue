<script setup>
import { VOnboardingWrapper, onboarding, obWrapper, onboardingSteps, onboardingOptions } from './onboarding.js'
</script>

<template>
  <VOnboardingWrapper ref="obWrapper" :steps="onboardingSteps" :options="onboardingOptions"/>
</template>
