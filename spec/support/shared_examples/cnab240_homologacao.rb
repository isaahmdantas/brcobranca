# -*- encoding: utf-8 -*-
shared_examples_for 'cnab240_homologacao' do
  let(:pagamento) do
    Brcobranca::Remessa::Pagamento.new(valor: 199.9,
      data_vencimento: Date.today,
      nosso_numero: 123,
      documento_sacado: '12345678901',
      nome_sacado: 'PABLO DIEGO JOSÉ FRANCISCO DE PAULA JUAN NEPOMUCENO MARÍA DE LOS REMEDIOS CIPRIANO DE LA SANTÍSSIMA TRINIDAD RUIZ Y PICASSO',
      endereco_sacado: 'RUA RIO GRANDE DO SUL São paulo Minas caçapa da silva junior',
      bairro_sacado: 'São josé dos quatro apostolos magros',
      cep_sacado: '12345678',
      cidade_sacado: 'Santa rita de cássia maria da silva',
      uf_sacado: 'SP',
      valor_iof: 9.9,
      valor_abatimento: 24.35,
      documento_avalista: '12345678901',
      nome_avalista: 'ISABEL CRISTINA LEOPOLDINA ALGUSTA MIGUELA GABRIELA RAFAELA GONZAGA DE BRAGANÇA E BOURBON',
      numero_documento: '00000000123')
  end
  let(:params) do
    p = {
      empresa_mae: 'SOCIEDADE BRASILEIRA DE ZOOLOGIA LTDA',
      agencia: '1234',
      conta_corrente: '12345',
      documento_cedente: '12345678901',
      convenio: '123456',
      sequencial_remessa: '1',
      mensagem_1: 'Campo destinado ao preenchimento no momento do pagamento.',
      mensagem_2: 'Campo destinado ao preenchimento no momento do pagamento.',
      pagamentos: [pagamento]
    }
  end
  let(:objeto) { subject.class.new(params) }

  context 'header arquivo' do
    it 'header arquivo deve ter 240 posicoes' do
      expect(objeto.monta_header_arquivo.size).to eq 240
    end

    it 'header arquivo deve ter as informacoes nas posicoes corretas' do
      header = objeto.monta_header_arquivo
      expect(header[0..2]).to eq objeto.cod_banco # cod. do banco
      expect(header[17]).to eq '1' # tipo inscricao do cedente
      expect(header[18..31]).to eq '00012345678901' # documento do cedente
      expect(header[32..51]).to eq objeto.codigo_convenio # informacoes do convenio
      expect(header[52..71]).to eq objeto.info_conta # informacoes da conta
      expect(header[72..101]).to eq 'SOCIEDADE BRASILEIRA DE ZOOLOG' # razao social do cedente
      expect(header[157..162]).to eq '000001' # sequencial de remessa
      expect(header[163..165]).to eq objeto.versao_layout_arquivo # versao do layout
    end
  end

  context 'header lote' do
    it 'header lote deve ter 240 posicoes' do
      expect(objeto.monta_header_lote(1).size).to eq 240
    end

    it 'header lote deve ter as informacoes nas posicoes corretas' do
      header = objeto.monta_header_lote 1
      expect(header[0..2]).to eq objeto.cod_banco # cod. do banco
      expect(header[3..6]).to eq '0001' # numero do lote
      expect(header[13..15]).to eq objeto.versao_layout_lote # versao do layout
      expect(header[17]).to eq '1' # tipo inscricao do cedente
      expect(header[18..32]).to eq '000012345678901' # documento do cedente
      expect(header[33..52]).to eq objeto.convenio_lote # informacoes do convenio
      expect(header[53..72]).to eq objeto.info_conta # informacoes da conta
      expect(header[73..102]).to eq 'SOCIEDADE BRASILEIRA DE ZOOLOG' # razao social do cedente
      expect(header[103..142]).to eq 'Campo destinado ao preenchimento no mome' # 1a mensagem
      expect(header[143..182]).to eq 'Campo destinado ao preenchimento no mome' # 2a mensagem
      expect(header[183..190]).to eq '00000001' # sequencial de remessa
    end
  end

  context 'segmento P' do
    it 'segmento P deve ter 240 posicoes' do
      expect(objeto.monta_segmento_p(pagamento, 1, 2).size).to eq 240
    end

    it 'segmento P deve ter as informacos nas posicoes corretas' do
      segmento_p = objeto.monta_segmento_p pagamento, 1, 2
      expect(segmento_p[0..2]).to eq objeto.cod_banco # codigo do banco
      expect(segmento_p[3..6]).to eq '0001' # numero do lote
      expect(segmento_p[8..12]).to eq '00002' # sequencial do registro no lote
      expect(segmento_p[17..21]).to eq '01234' # agencia
      expect(segmento_p[22]).to eq objeto.digito_agencia.to_s # digito da agencia
      expect(segmento_p[23..56]).to eq objeto.complemento_p(pagamento) # complemento do segmento P
      if objeto.cod_banco == '104'
        expect(segmento_p[62..76]).to eq '00000000123    ' # numero do documento
      else
        expect(segmento_p[62..76]).to eq '000000000000123' # numero do documento
      end
      expect(segmento_p[77..84]).to eq Date.today.strftime('%d%m%Y') # data de vencimento
      expect(segmento_p[85..99]).to eq '000000000019990' # valor
      expect(segmento_p[109..116]).to eq Date.today.strftime('%d%m%Y') # data de emissao
      # mora
      expect(segmento_p[141]).to eq '0' # codigo do desconto
      expect(segmento_p[142..149]).to eq '00000000' # data de desconto
      expect(segmento_p[150..164]).to eq ''.rjust(15, '0') # valor do desconto
      expect(segmento_p[165..179]).to eq '000000000000990' # valor do IOF
      expect(segmento_p[180..194]).to eq '000000000002435' # valor do abatimento
    end

    it 'segmento P deve ter as informações sobre o protesto' do
      pagamento.codigo_protesto = "1"
      pagamento.dias_protesto =  "6"
      segmento_p = objeto.monta_segmento_p pagamento, 1, 2

      expect(segmento_p[220]).to eq "1"
      expect(segmento_p[221..222]).to eq "06"
    end
  end

  context 'segmento Q' do
    it 'segmento Q deve ter 240 posicoes' do
      expect(objeto.monta_segmento_q(pagamento, 1, 3).size).to eq 240
    end

    it 'segmento Q deve ter as informacoes nas posicoes corretas' do
      segmento_q = objeto.monta_segmento_q pagamento, 1, 3
      expect(segmento_q[0..2]).to eq objeto.cod_banco # codigo do banco
      expect(segmento_q[3..6]).to eq '0001' # numero do lote
      expect(segmento_q[8..12]).to eq '00003' # numero do registro no lote
      expect(segmento_q[17]).to eq '1' # tipo inscricao sacado
      expect(segmento_q[18..32]).to eq '000012345678901' # documento do sacado
      expect(segmento_q[33..72]).to eq 'PABLO DIEGO JOSE FRANCISCO DE PAULA JUAN' # nome do sacado
      expect(segmento_q[73..112]).to eq 'RUA RIO GRANDE DO SUL Sao paulo Minas ca' # endereco do sacado
      expect(segmento_q[113..127]).to eq 'Sao jose dos qu' # bairro do sacado
      expect(segmento_q[128..132]).to eq '12345' # CEP do sacado
      expect(segmento_q[133..135]).to eq '678' # sufixo CEP do sacado
      expect(segmento_q[136..150]).to eq 'Santa rita de c' # cidade do sacado
      expect(segmento_q[151..152]).to eq 'SP' # UF do sacado
      expect(segmento_q[153]).to eq '1' # tipo inscricao avalista
      expect(segmento_q[154..168]).to eq '000012345678901' # documento avalista
      expect(segmento_q[169..208]).to eq 'ISABEL CRISTINA LEOPOLDINA ALGUSTA MIGUE' # nome do avalista
    end
  end

  context 'segmento R' do
    it 'segmento R deve ter 240 posicoes' do
      expect(objeto.monta_segmento_r(pagamento, 1, 4).size).to eq 240
    end

    it 'segmento R deve ter as informacoes nas posicoes corretas' do
      segmento_r = sicoob.monta_segmento_r(pagamento, 1, 4)
      expect(segmento_r[0..2]).to eq "756"                    # codigo banco
      expect(segmento_r[3..6]).to eq "0001"                   # lote de servico
      expect(segmento_r[7]).to eq "3"                         # tipo de registro
      expect(segmento_r[8..12]).to eq "00004"                 # nro seq. registro no lote
      expect(segmento_r[13]).to eq "R"                        # cod. segmento
      expect(segmento_r[14]).to eq " "                        # branco
      expect(segmento_r[15..16]).to eq "01"                   # cod. movimento remessa
      expect(segmento_r[17..40]).to eq "".rjust(24,  '0')     # desconto 2
      expect(segmento_r[41..64]).to eq "".rjust(24,  '0')     # desconto 3
      expect(segmento_r[65]).to eq '0'                        # cod. multa
      expect(segmento_r[66..73]).to eq ''.rjust(8, '0')       # data multa
      expect(segmento_r[74..88]).to eq ''.rjust(15, '0')      # valor multa
      expect(segmento_r[89..98]).to eq ''.rjust(10, ' ')      # info pagador
      expect(segmento_r[99..138]).to eq ''.rjust(40, ' ')     # mensagem 3
      expect(segmento_r[139..178]).to eq ''.rjust(40, ' ')    # mensagem 4
      expect(segmento_r[179..198]).to eq ''.rjust(20, ' ')    # Exclusivo FEBRABAN
      expect(segmento_r[199..206]).to eq ''.rjust(8, '0')     # Cod. Ocor Pagador
      expect(segmento_r[207..209]).to eq ''.rjust(3, '0')     # Cod. do Banco conta débito
      expect(segmento_r[210..214]).to eq ''.rjust(5, '0')     # Cod. da Agencia de  débito
      expect(segmento_r[215]).to eq ' '                       # Cod. verificador da agencia
      expect(segmento_r[216..227]).to eq ''.rjust(12, '0')    # Conta corrente para débito
      expect(segmento_r[228]).to eq ' '                       # Cod. verificador da conta
      expect(segmento_r[229]).to eq ' '                       # Cod. verificador da ag/conta
      expect(segmento_r[230]).to eq '0'                       # Aviso débito automático
      expect(segmento_r[231..239]).to eq ''.rjust(9, ' ')     # Exclusivo FEBRABAN

    end

  end

  context 'trailer lote' do
    it 'trailer lote deve ter 240 posicoes' do
      expect(objeto.monta_trailer_lote(1, 4).size).to eq 240
    end

    it 'trailer lote deve ter as informacoes nas posicoes corretas' do
      trailer = objeto.monta_trailer_lote 1, 4
      expect(trailer[0..2]).to eq objeto.cod_banco # cod. do banco
      expect(trailer[3..6]).to eq '0001' # numero do lote
      expect(trailer[17..22]).to eq '000004' # qtde de registros no lote
      expect(trailer[23..239]).to eq objeto.complemento_trailer # complemento do registro trailer
    end
  end

  context 'trailer arquivo' do
    it 'trailer arquivo deve ter 240 posicoes' do
      expect(objeto.monta_trailer_arquivo(1, 6).size).to eq 240
    end

    it 'trailer arquivo deve ter as informacoes nas posicoes corretas' do
      trailer = objeto.monta_trailer_arquivo 1, 6
      expect(trailer[0..2]).to eq objeto.cod_banco # cod. do banco
      expect(trailer[17..22]).to eq '000001' # qtde de lotes
      expect(trailer[23..28]).to eq '000006' # qtde de registros
    end
  end

  context 'monta lote' do
    it 'retorno de lote deve ser uma colecao com os registros' do
      lote = objeto.monta_lote(1)

      expect(lote.is_a?(Array)).to be true
      expect(lote.count).to be 5 # header, segmento p, segmento q, segmento r e trailer
    end

    it 'contador de registros deve acrescer 1 a cada registro' do
      lote = objeto.monta_lote(1)

      expect(lote[1][8..12]).to eq '00001' # segmento P
      expect(lote[2][8..12]).to eq '00002' # segmento Q
      expect(lote[3][8..12]).to eq '00003' # segmento R
      expect(lote[4][17..22]).to eq '000005' # trailer do lote
    end
  end

  context 'gera arquivo' do
    it 'deve falhar se o objeto for invalido' do
      expect { subject.class.new.gera_arquivo }.to raise_error(Brcobranca::RemessaInvalida)
    end

    it 'remessa deve conter os registros mais as quebras de linha' do
      remessa = objeto.gera_arquivo

      expect(remessa.size).to eq 1692
      # quebras de linha
      expect(remessa[240..241]).to eq "\r\n"
      expect(remessa[482..483]).to eq "\r\n"
      expect(remessa[724..725]).to eq "\r\n"
      expect(remessa[966..967]).to eq "\r\n"
      expect(remessa[1208..1209]).to eq "\r\n"
    end
  end
end
