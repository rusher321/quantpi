## reference
## https://github.com/biobakery/MetaPhlAn/wiki/StrainPhlAn-4


if config["params"]["profiling"]["strainphlan"]["do_v4"]:
    rule profiling_strainphlan4_sample2markers:
        input:
            database_pkl = expand(os.path.join(
                config["params"]["profiling"]["metaphlan"]["bowtie2db"], "{index}.pkl"),
                index = config["params"]["profiling"]["metaphlan"]["index_v4"]),
            sam = os.path.join(config["output"]["profiling"],
                               "profile/metaphlan4/{sample}/{sample}.sam.bz2"),
            aln = os.path.join(config["output"]["profiling"],
                               "profile/metaphlan4/{sample}/{sample}.bowtie2.bz2")
        output:
            os.path.join(
                config["output"]["profiling"],
                "profile/strainphlan4/consensus_markers/{sample}.pkl")
        log:
            os.path.join(
                config["output"]["profiling"],
                "logs/strainphlan4_sample2markers/{sample}.strainphlan4_sample2markers.log")
        benchmark:
            os.path.join(
                config["output"]["profiling"],
                "benchmark/strainphlan4_sample2markers/{sample}.strainphlan4_sample2markers.benchmark.txt")
        params:
            outdir =  os.path.join(config["output"]["profiling"], "profile/strainphlan4/consensus_markers")
        conda:
            config["envs"]["biobakery4"]
        priority:
            20
        threads:
            config["params"]["profiling"]["threads"]
        shell:
            '''
            sample2markers.py \
            --database {input.database_pkl} \
            --input {input.sam} \
            --output_dir {params.outdir}/ \
            --nprocs {threads} \
            > {log} 2>&1
            '''


    STRAINPHLAN_CLADES_V4 = \
        pd.read_csv(config["params"]["profiling"]["strainphlan"]["clades_tsv_v4"], sep="\t")\
          .set_index("clade")
    STRAINPHLAN_CLADES_LIST_V4 = STRAINPHLAN_CLADES_V4.index.unique()


    rule profiling_strainphlan4_extract_markers:
        input:
            database_pkl = expand(os.path.join(
                config["params"]["profiling"]["metaphlan"]["bowtie2db"], "{index}.pkl"),
                index = config["params"]["profiling"]["metaphlan"]["index_v4"])
        output:
            clade_marker = os.path.join(
                config["output"]["profiling"],
                "databases/strainphlan4/clade_markers/{clade}/{clade}.fna")
        log:
            os.path.join(
                config["output"]["profiling"], 
                "logs/strainphlan4_extract_markers/{clade}.strainphlan4_extract_markers.log")
        benchmark:
            os.path.join(
                config["output"]["profiling"],
                "benchmark/strainphlan4_extract_markers/{clade}.strainphlan4_extract_markers.benchmark.txt")
        conda:
            config["envs"]["biobakery4"]
        params:
            clade = "{clade}",
            outdir = os.path.join(config["output"]["profiling"], "databases/strainphlan4/clade_markers/{clade}")
        priority:
            20
        threads:
            config["params"]["profiling"]["threads"]
        shell:
            '''
            mkdir -p {params.outdir}

            extract_markers.py \
            --database {input.database_pkl} \
            --clade {params.clade} \
            --output_dir {params.outdir}/ \
            > {log} 2>&1
            '''


    rule profiling_strainphlan4_prepare_reference_genome:
        input:
            reference_genome = lambda wildcards: STRAINPHLAN_CLADES_V4.loc[wildcards.clade, "fna_path"]
        output:
            reference_genome = os.path.join(
                config["output"]["profiling"],
                "databases/strainphlan4/reference_genomes/{clade}.fna")
        run:
            if input.reference_genome.endswith(".gz"):
                shell(f'''pigz -fkdc {input.reference_genome} > {output.reference_genome}''')
            else:
                fna_path = os.path.realpath(input.reference_genome)
                fna_path_ = os.path.realpath(output.reference_genome)
                shellf('''ln -s {fna_path} {fna_path_}''')


    localrules:
        profiling_strainphlan4_prepare_reference_genome


    rule profiling_strainphlan4:
        input:
            database_pkl = expand(os.path.join(
                config["params"]["profiling"]["metaphlan"]["bowtie2db"], "{index}.pkl"),
                index = config["params"]["profiling"]["metaphlan"]["index_v4"]),
            clade_marker = os.path.join(
                config["output"]["profiling"],
                "databases/strainphlan4/clade_markers/{clade}/{clade}.fna"),
            consensus_markers = expand(os.path.join(
                config["output"]["profiling"],
                "profile/strainphlan4/consensus_markers/{sample}.pkl"),
                sample=SAMPLES_ID_LIST),
            reference_genome = os.path.join(
                config["output"]["profiling"],
                "databases/strainphlan4/reference_genomes/{clade}.fna")
        output:
            #expand(os.path.join(
            #    config["output"]["profiling"],
            #    "profile/strainphlan4/clade_markers/{{clade}}/RAxML_{prefix}.{{clade}}.StrainPhlAn4.tre"),
            #    prefix=["bestTree", "info", "log", "parsimonyTree", "result"]),
            #expand(os.path.join(
            #    config["output"]["profiling"],
            #    "profile/strainphlan4/clade_markers/{{clade}}/{{clade}}{suffix}"),
            #    suffix=[".info", ".mutation", ".polymorphic",
            #            ".StrainPhlAn4_concatenated.aln"]),
            #directory(os.path.join(
            #    config["output"]["profiling"],
            #    "profile/strainphlan4/clade_markers/{clade}/{clade}_mutation_rates"))
            done = os.path.join(config["output"]["profiling"], "profile/strainphlan4/clade_markers/{clade}/done")
        log:
            os.path.join(
                config["output"]["profiling"],
                "logs/strainphlan4/{clade}.strainphlan4.log")
        benchmark:
            os.path.join(
                config["output"]["profiling"],
                "benchmark/strainphlan4/{clade}.strainphlan4.benchmark.txt")
        conda:
            config["envs"]["biobakery4"]
        params:
            clade = "{clade}",
            outdir = os.path.join(config["output"]["profiling"], "profile/strainphlan4/clade_markers/{clade}"),
            trim_sequences = config["params"]["profiling"]["strainphlan"]["trim_sequences"],
            marker_in_n_samples = config["params"]["profiling"]["strainphlan"]["marker_in_n_samples"],
            sample_with_n_markers = config["params"]["profiling"]["strainphlan"]["sample_with_n_markers"],
            secondary_sample_with_n_markers = config["params"]["profiling"]["strainphlan"]["secondary_sample_with_n_markers"],
            #sample_with_n_markers_after_filt = config["params"]["profiling"]["strainphlan"]["sample_with_n_markers_after_filt"],
            breadth_thres = config["params"]["profiling"]["strainphlan"]["breadth_thres"],
            phylophlan_mode = config["params"]["profiling"]["strainphlan"]["phylophlan_mode"],
            opts = config["params"]["profiling"]["strainphlan"]["external_opts_v4"]
        priority:
            20
        threads:
            config["params"]["profiling"]["threads"]
        shell:
            '''
            rm -rf {params.outdir}
            mkdir -p {params.outdir}

            strainphlan \
            --database {input.database_pkl} \
            --samples {input.consensus_markers} \
            --clade_markers {input.clade_marker} \
            --references {input.reference_genome} \
            --output_dir {params.outdir}/ \
            --nprocs {threads} \
            --clade {params.clade} \
            --trim_sequences {params.trim_sequences} \
            --marker_in_n_samples {params.marker_in_n_samples} \
            --sample_with_n_markers {params.sample_with_n_markers} \
            --secondary_sample_with_n_markers {params.secondary_sample_with_n_markers} \
            --breadth_thres {params.breadth_thres} \
            --phylophlan_mode {params.phylophlan_mode} \
            --mutation_rates \
            {params.opts} \
            >{log} 2>&1

            touch {output.done}
            '''


    rule profiling_strainphlan4_all:
        input:
            #expand(os.path.join(
            #    config["output"]["profiling"],
            #    "profile/strainphlan4/clade_markers/{clade}/RAxML_{prefix}.{clade}.StrainPhlAn4.tre"),
            #    prefix=["bestTree", "info", "log", "parsimonyTree", "result"],
            #    clade=STRAINPHLAN_CLADES_LIST_V4),
            #expand(os.path.join(
            #    config["output"]["profiling"],
            #    "profile/strainphlan4/clade_markers/{clade}/{clade}{suffix}"),
            #    suffix=["_mutation_rates", ".info", ".mutation", ".polymorphic",
            #            ".StrainPhlAn4_concatenated.aln"],
            #    clade=STRAINPHLAN_CLADES_LIST_V4)
            expand(os.path.join(
                config["output"]["profiling"],
                "profile/strainphlan4/clade_markers/{clade}/done"),
                clade=STRAINPHLAN_CLADES_LIST_V4)

else:
    rule profiling_strainphlan4_all:
        input: