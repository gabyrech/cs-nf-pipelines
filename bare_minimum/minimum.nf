#!/usr/bin/env nextflow

params.fq_path = "$HOME/sample.fa" // default
params.outdir = "."
println params.fq_path
println params.fq_path

process foo {
  println "success"
  '''
  do this
  '''
}

process bar {
  println "or so we think"
  '''
  do that
  '''
}
