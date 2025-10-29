// Simple Hello World Camel K integration
from('timer:hello?period=10000')
    .setBody(constant('Hello World from Camel K on AKS!'))
    .log('${body}')