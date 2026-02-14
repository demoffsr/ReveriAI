export default {
  multipass: true,
  plugins: [
    {
      name: 'preset-default',
      params: {
        overrides: {
          removeViewBox: false,
          cleanupIds: true,
          removeHiddenElems: true,
          removeEmptyText: true,
          convertPathData: {
            floatPrecision: 1
          },
          convertTransform: {
            floatPrecision: 1
          },
          cleanupNumericValues: {
            floatPrecision: 1
          }
        }
      }
    },
    'removeDoctype',
    'removeComments',
    'removeMetadata',
    'removeXMLProcInst',
    'removeEditorsNSData',
    'removeTitle',
    'removeDesc',
    'sortAttrs',
    'sortDefsChildren'
  ]
};
