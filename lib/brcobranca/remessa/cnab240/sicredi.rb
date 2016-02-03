# -*- encoding: utf-8 -*-
module Brcobranca
  module Remessa
    module Cnab240
      class Sicredi < Brcobranca::Remessa::Cnab240::Base
        attr_accessor :modalidade_carteira
        attr_accessor :parcela
        #       Parcela - 02 posições (11 a 12) - "01" se parcela única

        attr_accessor :byte_idt
        attr_accessor :posto

        validates_presence_of :byte_idt, :modalidade_carteira, :parcela, :posto,
          message: 'não pode estar em branco.'

        # Remessa 240 - 12 digitos
        validates_length_of :conta_corrente, maximum: 8, message: 'deve ter 8 dígitos.'
        validates_length_of :agencia, is: 4, message: 'deve ter 4 dígitos.'
        validates_length_of :modalidade_carteira, is: 2, message: 'deve ter 2 dígitos.'
        validates_length_of :posto, maximum: 2, message: 'deve ser menor ou igual a 2 dígitos.'
        validates_length_of :byte_idt, is: 1,
          message: 'deve ser 1 se o numero foi gerado pela agencia ou 2-9 se foi gerado pelo beneficiário'

        def initialize(campos = {})
          campos = { emissao_boleto: '2',
                     distribuicao_boleto: '2',
                     especie_titulo: '03',
                     parcela: '01',
                     modalidade_carteira: '01',
                     forma_cadastramento: '1',
                     tipo_documento: '1',
                     codigo_protesto: '3',
                     codigo_baixa: '1',
                     dias_baixa: '060' }.merge!(campos)
          super(campos)
        end

        def cod_banco
          '748'
        end

        def nome_banco
          'SICREDI'.ljust(30, ' ')
        end

        def versao_layout_arquivo
          '081'
        end

        def versao_layout_lote
          '040'
        end

        def densidade_gravacao
          '01600'
        end

        def digito_agencia
          # utilizando a agencia com 4 digitos
          # para calcular o digito
          agencia.modulo11(mapeamento: { 10 => 'X' }).to_s
        end

        def digito_conta
          # utilizando a conta corrente com 5 digitos
          # para calcular o digito
          conta_corrente.modulo11(mapeamento: { 10 => 'X' }).to_s
        end

        def codigo_convenio
          # CAMPO                TAMANHO
          # num. convenio        20 BRANCOS
          ''.rjust(20, ' ')
        end

        alias_method :convenio_lote, :codigo_convenio

        def info_conta
          # CAMPO                  TAMANHO
          # agencia                5
          # digito agencia         1
          # conta corrente         12
          # digito conta           1
          # digito agencia/conta   1
          "#{agencia.rjust(5, '0')}#{digito_agencia}#{conta_corrente.rjust(12, '0')}#{digito_conta} "
        end

        def complemento_header
          ''.rjust(29, ' ')
        end

        def quantidade_titulos_cobranca
          pagamentos.length.to_s.rjust(6, "0")
        end

        def totaliza_valor_titulos
          pagamentos.inject(0) { |sum, pag| sum += pag.valor.to_f }
        end

        def valor_titulos_carteira
          total = sprintf "%.2f", totaliza_valor_titulos
          total.somente_numeros.rjust(17, "0")
        end

        def complemento_trailer
          # CAMPO                               TAMANHO
          # Qt. Títulos em Cobrança Simples     6
          # Vl. Títulos em Carteira Simples     15 + 2 decimais
          # Qt. Títulos em Cobrança Vinculada   6
          # Vl. Títulos em Carteira Vinculada   15 + 2 decimais
          # Qt. Títulos em Cobrança Caucionada  6
          # Vl. Títulos em Carteira Caucionada  15 + 2 decimais
          # Qt. Títulos em Cobrança Descontada  6
          # Vl. Títulos em Carteira Descontada  15 + 2 decimais
          total_cobranca_simples    = "#{quantidade_titulos_cobranca}#{valor_titulos_carteira}"
          total_cobranca_vinculada  = "".rjust(23, "0")
          total_cobranca_caucionada = "".rjust(23, "0")
          total_cobranca_descontada = "".rjust(23, "0")

          "#{total_cobranca_simples}#{total_cobranca_vinculada}#{total_cobranca_caucionada}"\
            "#{total_cobranca_descontada}".ljust(217, ' ')
        end

        # Monta o registro trailer do arquivo
        #
        # @param nro_lotes [Integer]
        #   numero de lotes no arquivo
        # @param sequencial [Integer]
        #   numero de registros(linhas) no arquivo
        #
        # @return [String]
        #
        def monta_trailer_arquivo(nro_lotes, sequencial)
          # CAMPO                     TAMANHO
          # codigo banco              3
          # lote de servico           4
          # tipo de registro          1
          # uso FEBRABAN              9
          # nro de lotes              6
          # nro de registros(linhas)  6
          # uso FEBRABAN              211
          "#{cod_banco}99999#{''.rjust(9, ' ')}#{nro_lotes.to_s.rjust(6, '0')}#{sequencial.to_s.rjust(6, '0')}#{''.rjust(6, '0')}#{''.rjust(205, ' ')}"
        end

        def complemento_p(pagamento)
          # CAMPO                   TAMANHO
          # conta corrente          12
          # digito conta            1
          # digito agencia/conta    1
          # ident. titulo no banco  20
          "#{conta_corrente.rjust(12, '0')}#{digito_conta} #{formata_nosso_numero(pagamento.nosso_numero)}"
        end

        # Retorna o nosso numero
        #
        # @return [String]
        def formata_nosso_numero(nosso_numero)
          "#{nosso_numero_with_byte_idt(nosso_numero)}#{nosso_numero_dv(nosso_numero)}"
        end

        def nosso_numero_with_byte_idt(nosso_numero)
          "#{Time.now.strftime('%y')}#{byte_idt}#{nosso_numero.to_s.rjust(16, "0")}"
        end

        # Dígito verificador do nosso número
        # @return [Integer] 1 caracteres numéricos.
        def nosso_numero_dv(nosso_numero)
          "#{agencia_posto_conta}#{nosso_numero_with_byte_idt(nosso_numero)}"
            .modulo11(mapeamento: mapeamento_para_modulo_11)
        end

        def agencia_conta_boleto
          "#{agencia}.#{posto}.#{conta_corrente}"
        end

        def agencia_posto_conta
          "#{agencia}#{posto}#{conta_corrente}"
        end

        private

        def mapeamento_para_modulo_11
          {
            10 => 0,
            11 => 0
          }
        end
      end
    end
  end
end