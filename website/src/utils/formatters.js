const integerFormatter = new Intl.NumberFormat('en-US', {
  maximumFractionDigits: 0,
})

export const formatInteger = (value) => integerFormatter.format(value)
export const formatTime = (value) => `${(value / 1000).toFixed(3)}s`
export const formatPercentage = (value) => `${Number(value).toFixed(2)}%`
export const formatReaction = (value) => `${Math.round(value)}ms`
export const formatDate = (value) =>
  new Date(value).toISOString().slice(0, 10).replaceAll('-', '.')
